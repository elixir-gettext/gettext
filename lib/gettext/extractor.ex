defmodule Gettext.Extractor do
  @moduledoc false

  alias Gettext.ExtractorAgent
  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation
  alias Gettext.Error

  @doc """
  Performs some generic setup needed to extract translations from source.

  For example, starts the agent that stores the translations while they're
  extracted and other similar tasks.
  """
  @spec setup() :: :ok
  def setup do
    {:ok, _} = ExtractorAgent.start_link
    :ok
  end

  @doc """
  Performs teardown after the sources have been extracted.

  For now, it only stops the agent that stores the translations.
  """
  @spec teardown() :: :ok
  def teardown do
    :ok = ExtractorAgent.stop
  end

  @doc """
  Tells whether translations are being extracted.
  """
  @spec extracting?() :: boolean
  def extracting? do
    ExtractorAgent.alive?
  end

  @doc """
  Extracts a translation by temporarily storing it in an agent.

  Note that this function doesn't perform any operation on the filesystem.
  """
  @spec extract(Macro.Env.t, module, binary, binary | {binary, binary}) :: :ok
  def extract(%Macro.Env{file: file, line: line} = _caller, backend, domain, id) do
    ExtractorAgent.add_translation(backend, domain, create_translation_struct(id, file, line))
  end

  @doc """
  Returns a list of POT files based o the results of the extraction.

  Returns a list of paths and their contents to be written to disk. Existing POT
  files are either purged from obsolete translations (in case no extracted
  translation ends up in that file) or merged with the extracted translations;
  new POT files are returned for extracted translations that belong to a POT
  file that doesn't exist yet.
  """
  @spec pot_files() :: [{path :: String.t, contents :: iodata}]
  def pot_files do
    existing_pot_files = pot_files_for_backends(ExtractorAgent.get_backends)
    po_structs = create_po_structs_from_extracted_translations(ExtractorAgent.get_translations)
    merge_pot_files(existing_pot_files, po_structs)
  end

  # Returns all the .pot files for each of the given `backends`.
  defp pot_files_for_backends(backends) do
    Enum.flat_map backends, fn backend ->
      backend.__gettext__(:priv)
      |> Path.join("**/*.pot")
      |> Path.wildcard()
    end
  end

  # This returns a list of {absolute_path, %Gettext.PO{}} tuples.
  # `all_translations` looks like this:
  #
  #     %{MyBackend => %{"a_domain" => %{"a translation id" => a_translation}}}
  #
  defp create_po_structs_from_extracted_translations(all_translations) do
    for {backend, domains}     <- all_translations,
        {domain, translations} <- domains do
      create_po_struct(backend, domain, Map.values(translations))
    end
  end

  # Returns a {path, %Gettext.PO{}} tuple.
  defp create_po_struct(backend, domain, translations) do
    {pot_path(backend, domain), po_struct_from_translations(translations)}
  end

  defp pot_path(backend, domain) do
    Path.join(backend.__gettext__(:priv), "#{domain}.pot")
  end

  defp po_struct_from_translations(translations) do
    # Sort all the translations and the references of each translation in order
    # to make as few changes as possible to the PO(T) files.
    translations =
      translations
      |> Enum.sort_by(&PO.Translations.key/1)
      |> Enum.map(&sort_references/1)

    %PO{translations: translations}
  end

  defp sort_references(translation) do
    update_in(translation.references, &Enum.sort/1)
  end

  defp create_translation_struct({msgid, msgid_plural}, file, line),
    do: %PluralTranslation{
          msgid: [msgid],
          msgid_plural: [msgid_plural],
          msgstr: %{0 => [""], 1 => [""]},
          references: [{Path.relative_to_cwd(file), line}],
        }
  defp create_translation_struct(msgid, file, line),
    do: %Translation{
          msgid: [msgid],
          msgstr: [""],
          references: [{Path.relative_to_cwd(file), line}],
        }

  # Made public for testing.
  @doc false
  def merge_pot_files(pot_files, po_structs) do
    # pot_files is a list of paths to existing .pot files while po_structs is a
    # list of {path, struct} for new %Gettext.PO{} structs that we have
    # extracted. If we turn pot_files into a list of {path, whatever} tuples,
    # that we can take advantage of Dict.merge/3 to find clashing paths.
    pot_files  = Enum.into(pot_files, %{}, &{&1, :existing})
    po_structs = Enum.into(po_structs, %{})

    Map.merge(pot_files, po_structs, &merge_existing_and_extracted/3)
    |> Enum.map(&tag_files/1)
    |> Enum.reject(&match?({_, {_, :unchanged}}, &1))
    |> Enum.map(&dump_tagged_file/1)
  end

  defp merge_existing_and_extracted(path, :existing, extracted) do
    {:merged, merge_or_unchanged(path, extracted)}
  end

  # Returns :unchanged if merging `existing_path` with `new` changes nothing,
  # otherwise a %Gettext.PO{} struct with the changed contents.
  defp merge_or_unchanged(existing_path, new_struct) do
    existing_contents = File.read!(existing_path)
    merged =
      existing_contents
      |> PO.parse_string!()
      |> merge_template(new_struct)

    if IO.iodata_to_binary(PO.dump(merged)) == existing_contents do
      :unchanged
    else
      merged
    end
  end

  # This function "tags" a {path, _} tuple in order to distinguish POT files
  # that have been merged (one existed at `path` and there's a new one to put at
  # `path` as well), POT files that exist but have no new counterpart (`{path,
  # :existing}`) and new files that do not exist yet.
  # These are marked as:
  #   * {path, {:merged, _}} - one existed and there's a new one
  #   * {path, {:unmerged, _}} - one existed, no new one
  #   * {path, {:new, _}} - none existed, there's a new one
  # Note that existing files with no new corresponding file are "pruned", e.g.,
  # merged with an empty %PO{} struct to remove obsolete translations (see
  # prune_unmerged/1).
  defp tag_files({_path, {:merged, _}} = entry),
    do: entry
  defp tag_files({path, :existing}),
    do: {path, {:unmerged, prune_unmerged(path)}}
  defp tag_files({path, new_po}),
    do: {path, {:new, new_po}}

  # This function "dumps" merged files and unmerged files without any changes,
  # and dumps new POT files adding an informative comment to them. This doesn't
  # write anything to disk, it just returns `{path, contents}` tuples.
  defp dump_tagged_file({path, {:new, new_po}}),
    do: {path, [new_pot_comment(), (new_po |> add_headers_to_new_po() |> PO.dump())]}
  defp dump_tagged_file({path, {tag, po}}) when tag in [:unmerged, :merged],
    do: {path, PO.dump(po)}

  defp prune_unmerged(path) do
    merge_or_unchanged(path, %PO{})
  end

  defp new_pot_comment do
    """
    ## This file is a PO Template file.
    ##
    ## `msgid`s here are often extracted from source code.
    ## Add new translations manually only if they're dynamic
    ## translations that can't be statically extracted.
    ##
    ## Run `mix gettext.extract` to bring this file up to
    ## date. Leave `msgstr`s empty as changing them here as no
    ## effect: edit them in PO (`.po`) files instead.
    """
  end

  defp add_headers_to_new_po(%PO{headers: []} = po) do
    %{po | headers: ["", "Language: INSERT LANGUAGE HERE\n"]}
  end

  # Merges a %PO{} struct representing an existing POT file with an
  # in-memory-only %PO{} struct representing the new POT file.
  # Made public for testing.
  @doc false
  def merge_template(existing, new) do
    protected_pattern = Application.get_env(:gettext, :excluded_refs_from_purging)
    old_and_merged = Enum.flat_map existing.translations, fn(t) ->
      cond do
        same = PO.Translations.find(new.translations, t) ->
          [merge_translations(t, same)]
        PO.Translations.protected?(t, protected_pattern) ->
          [t]
        PO.Translations.autogenerated?(t) ->
          []
        true ->
          [t]
      end
    end

    # We reject all translations that appear in `existing` so that we're left
    # with the translations that only appear in `new`.
    unique_new = Enum.reject(new.translations, &PO.Translations.find(existing.translations, &1))

    %PO{translations: old_and_merged ++ unique_new,
        headers: existing.headers,
        top_of_the_file_comments: existing.top_of_the_file_comments}
  end

  defp merge_translations(%Translation{} = old, %Translation{comments: []} = new) do
    ensure_empty_msgstr!(old)
    ensure_empty_msgstr!(new)
    %Translation{
      msgid: old.msgid,
      msgstr: old.msgstr,
      # The new in-memory translation has no comments.
      comments: old.comments,
      references: new.references,
    }
  end

  defp merge_translations(%PluralTranslation{} = old, %PluralTranslation{comments: []} = new) do
    ensure_empty_msgstr!(old)
    ensure_empty_msgstr!(new)
    %PluralTranslation{
      msgid: old.msgid,
      msgid_plural: old.msgid_plural,
      msgstr: old.msgstr,
      # The new in-memory translation has no comments.
      comments: old.comments,
      references: new.references,
    }
  end

  defp ensure_empty_msgstr!(%Translation{msgstr: msgstr} = t) do
    unless blank?(msgstr) do
      raise Error, "translation with msgid '#{IO.iodata_to_binary(t.msgid)}' has a non-empty msgstr"
    end
  end

  defp ensure_empty_msgstr!(%PluralTranslation{msgstr: %{0 => str0, 1 => str1}} = t) do
    if not blank?(str0) or not blank?(str1) do
      raise Error,
        "plural translation with msgid '#{IO.iodata_to_binary(t.msgid)}' has a non-empty msgstr"
    end
  end

  defp ensure_empty_msgstr!(%PluralTranslation{} = t) do
    raise Error,
      "plural translation with msgid '#{IO.iodata_to_binary(t.msgid)}' has a non-empty msgstr"
  end

  defp blank?(nil), do: true
  defp blank?(str), do: IO.iodata_length(str) == 0
end
