defmodule Gettext.Extractor do
  @doc false

  alias Gettext.ExtractorAgent
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  @doc """
  Performs some generic setup needed to extract translations from source.

  For example, starts the agent that stores the translations while they're
  extracted and other similar tasks.
  """
  @spec setup_for_extraction() :: :ok
  def setup_for_extraction do
    Application.put_env(:gettext, :extract_translations, true)
    ExtractorAgent.start_link
    :ok
  end

  @doc """
  Tells whether translations are being extracted.
  """
  @spec extracting?() :: boolean
  def extracting? do
    Application.get_env(:gettext, :extract_translations, false)
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
  """
  @spec process_results() :: :ok
  def process_results do
    for {backend, domains} <- ExtractorAgent.get_all,
        {domain, translations} <- domains do
      merge_or_create_pot_file(backend, domain, translations)
    end

    :ok
  end

  defp create_translation_struct({msgid, msgid_plural}, file, line),
    do: %PluralTranslation{
          msgid: [msgid],
          msgid_plural: [msgid_plural],
          msgstr: %{0 => [""], 1 => [""]},
          references: [{file, line}],
        }
  defp create_translation_struct(msgid, file, line),
    do: %Translation{
          msgid: [msgid],
          msgstr: [""],
          references: [{file, line}],
        }

  defp merge_or_create_pot_file(backend, domain, translations) do
    pot_path = pot_path(backend, domain)
    new_pot  = pot_file(translations)

    if File.exists?(pot_path) do
      old_pot = Gettext.PO.parse_file!(pot_path)
      new_pot = Gettext.PO.merge(old_pot, new_pot)
    end

    File.write!(pot_path, Gettext.PO.dump(new_pot))
  end

  defp pot_file(translations) do
    # First, let's sort all the translations.
    translations = Enum.sort_by translations, fn
      %Translation{msgid: id, references: refs} ->
        {id, refs}
      %PluralTranslation{msgid: id, msgid_plural: idp, references: refs} ->
        {id, idp, refs}
    end

    # Let's sort the references as well.
    translations = Enum.map(translations, &(%{&1 | references: Enum.sort(&1.references)}))

    %Gettext.PO{translations: translations}
  end

  defp pot_path(backend, domain) do
    Path.join(backend.__gettext_dir__(), "#{domain}.pot")
  end
end
