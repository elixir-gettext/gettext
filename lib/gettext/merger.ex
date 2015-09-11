defmodule Gettext.Merger do
  @moduledoc false

  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  @doc """
  Merges a PO file with a POT file given their paths.

  This function returns the contents (as iodata) of the merged file, which will
  be written to a PO file.
  """
  @spec merge_files(Path.t, Path.t) :: iodata
  def merge_files(po_file, pot_file) do
    merge(PO.parse_file!(po_file), PO.parse_file!(pot_file)) |> PO.dump
  end

  @doc """
  Merges two `Gettext.PO` structs representing a PO file and an updated POT (or
  PO) file into a new `Gettext.PO` struct. `old` is an existing PO file (that
  contains translations) which will be "updated" with the translations in the
  `new` POT or PO file. Translations in `old` will kept as long as they match
  with translations in `new`; all other translations will be discarded (as `new`
  is considered to be the reference).

  `new` can be:

    * a POT file (usually created or updated by the `mix gettext.extract` task) or
    * a newly created PO file with up-to-date source references (but old translations)

  Note that all translator comments in `new` will be discarded in favour of the
  ones in `old`. Reference comments and extracted comments will be taken from
  `new` instead.

  The following rules are observed:

    * matching translations are merged as follows:
      * existing msgstr are preserved (the ones in the POT file are empty anyways)
      * existing translator comments are preserved (there are no translator
        comments in POT files)
      * existing references are discarded (as they're now outdated) and replaced
        by the references in the POT file

  """
  @spec merge(PO.t, PO.t) :: PO.t
  def merge(%PO{} = old, %PO{} = new) do
    %PO{
      headers: old.headers,
      file: old.file,
      translations: merge_translations(old.translations, new.translations),
    }
  end

  defp merge_translations(old, new) do
    merged = Enum.flat_map old, fn(t) ->
      if same = PO.Translations.find(new, t) do
        [merge_two_translations(t, same)]
      else
        []
      end
    end

    new = Enum.reject(new, &PO.Translations.find(old, &1))

    merged ++ new
  end

  defp merge_two_translations(%Translation{} = old, %Translation{} = new) do
    %Translation{
      msgid: new.msgid, # they are the same
      msgstr: old.msgstr, # new.msgstr should be empty since it's a POT file
      comments: old.comments, # new has no translator comments
      references: new.references,
    }
  end

  defp merge_two_translations(%PluralTranslation{} = old, %PluralTranslation{} = new) do
    %PluralTranslation{
      msgid: new.msgid, # they are the same
      msgid_plural: new.msgid_plural, # they are the same
      msgstr: old.msgstr, # new.msgstr should be empty since it's a POT file
      comments: old.comments, # new has no translator comments
      references: new.references,
    }
  end

  @doc """
  Returns the contents of a new PO file to be written at `po_file` from the POT
  template in `pot_file`.

  The new PO file will have:

    * the `Language` header set based on the locale (extracted from the path)
    * the translations of the POT file (no merging is needed as there are no
      translations in the PO file)

  """
  @spec new_po_file(Path.t, Path.t) :: iodata
  def new_po_file(po_file, pot_file) do
    pot = PO.parse_file!(pot_file)
    po = %PO{
      headers: headers_for_new_po_file(po_file),
      file: po_file,
      translations: pot.translations,
    }

    PO.dump(po)
  end

  defp headers_for_new_po_file(po_file) do
    [
      ~s(Language: #{locale_from_path(po_file)}\n),
    ]
  end

  defp locale_from_path(path) do
    parts = Path.split(path)
    index = Enum.find_index(parts, &(&1 == "LC_MESSAGES"))
    Enum.at(parts, index - 1)
  end
end
