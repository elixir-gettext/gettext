defmodule Gettext.Extractor do
  @moduledoc false

  alias Gettext.ExtractorAgent
  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  @doc """
  Performs some generic setup needed to extract translations from source.

  For example, starts the agent that stores the translations while they're
  extracted and other similar tasks.
  """
  @spec setup() :: :ok
  def setup do
    ExtractorAgent.start_link
    :ok
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
  Writes or merges POT files based on the results of the extraction.

  Returns a list of paths and their contents to be written to disk.
  """
  @spec dump_pot() :: [{path :: String.t, contents :: binary}]
  def dump_pot do
    extracted_translations = ExtractorAgent.get_translations
    existing_pot_files = pot_files_for_backends(ExtractorAgent.get_backends)
    po_structs = create_po_structs_from_extracted_translations(extracted_translations)
    merge_pot_files(existing_pot_files, po_structs)
  after
    ExtractorAgent.stop
  end

  # This returns a list of {absolute_path, %Gettext.PO{}} tuples.
  defp create_po_structs_from_extracted_translations(all_translations) do
    for {backend, domains}     <- all_translations,
        {domain, translations} <- domains do
      create_po_struct(backend, domain, Map.values(translations))
    end
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

  defp create_po_struct(backend, domain, translations) do
    pot_path = pot_path(backend, domain)
    pot      = pot_file(translations)
    {pot_path, pot}
  end

  defp pot_file(translations) do
    # Sort all the translations and the references of each translation in order
    # to make as few changes as possible to the PO(T) files.
    translations =
      translations
      |> Enum.sort_by(&PO.Translations.key/1)
      |> Enum.map(&sort_references/1)

    %PO{translations: translations}
  end

  defp pot_path(backend, domain) do
    Path.join(backend.__gettext__(:priv), "#{domain}.pot")
  end

  defp sort_references(translation) do
    update_in(translation.references, &Enum.sort/1)
  end

  defp pot_files_for_backends(backends) do
    Enum.flat_map(backends, &pot_files_for_backend/1)
  end

  defp pot_files_for_backend(backend) do
    backend.__gettext__(:priv)
    |> Path.join("**/*.pot")
    |> Path.wildcard
  end

  # Made public for testing.
  @doc false
  def merge_pot_files(pot_files, po_structs) do
    # pot_files is a list of paths to existing .pot files while po_structs is a
    # list of {path, struct} for new %Gettext.PO{} struct that we have
    # extracted. If we turn pot_files into a list of {path, whatever} tuples,
    # that we can take advantage of Dict.merge/3 to find clashing paths.
    pot_files
    |> Enum.map(&{&1, :existing})
    |> Enum.into(%{})
    |> Map.merge(Enum.into(po_structs, %{}), &merge_existing_and_extracted/3)
    |> Enum.map(&purge_unmerged_files/1)
    |> Enum.map(fn({path, pot}) -> {path, PO.dump(pot)} end)
  end

  defp merge_existing_and_extracted(path, :existing, extracted) do
    path |> PO.parse_file! |> PO.merge(extracted)
  end

  defp purge_unmerged_files({path, :existing}),
    do: {path, path |> PO.parse_file! |> PO.merge(%PO{})}
  defp purge_unmerged_files(already_merged),
    do: already_merged
end
