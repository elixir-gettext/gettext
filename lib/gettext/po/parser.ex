defmodule Gettext.PO.Parser do
  @moduledoc false

  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  @doc """
  Parses a list of tokens into a list of translations.
  """
  @spec parse([Gettext.PO.Tokenizer.token]) ::
    {:ok, [binary], [Gettext.PO.translation]} | Gettext.PO.parse_error
  def parse(tokens) do
    case :gettext_po_parser.parse(tokens) do
      {:ok, translations} ->
        do_parse(translations)
      {:error, _reason} = error ->
        parse_error(error)
    end
  end

  defp do_parse(translations) do
    translations = Enum.map(translations, &to_struct/1)

    case check_for_duplicates(translations) do
      {:error, _line, _reason} = error ->
        error
      :ok ->
        {headers, translations} = extract_headers(translations)
        {:ok, headers, translations}
    end
  end

  defp to_struct({:translation, translation}),
    do: struct(Translation, translation) |> extract_references()
  defp to_struct({:plural_translation, translation}),
    do: struct(PluralTranslation, translation) |> extract_references()

  defp parse_error({:error, {line, _module, reason}}) do
    {:error, line, IO.chardata_to_string(reason)}
  end

  defp extract_references(%{__struct__: _, comments: comments} = translation) do
    references =
      for "#:" <> contents <- comments,
        (contents = String.strip(contents)) != "",
        do: parse_reference(contents)

    %{translation | references: references}
  end

  defp parse_reference(ref) do
    [file, line] = String.split(ref, ":")
    {file, String.to_integer(line)}
  end

  # If the first translation has an empty msgid, it's assumed to represent
  # headers. Headers will be in the msgstr of this "fake" translation, one on
  # each line. For now, we'll just separate those lines in order to get a list
  # of headers.
  defp extract_headers([%Translation{msgid: id, msgstr: headers}|rest])
    when id == "" or id == [""],
    do: {headers, rest}
  defp extract_headers(translations),
    do: {[], translations}

  defp check_for_duplicates(translations) do
    if duplicates = (translations |> group_translations_by_id |> find_duplicates) do
      build_duplicate_error(duplicates)
    else
      :ok
    end
  end

  defp group_translations_by_id(translations) do
    Enum.group_by translations, fn
      %Translation{msgid: id}                          -> id
      %PluralTranslation{msgid: id, msgid_plural: idp} -> {id, idp}
    end
  end

  defp find_duplicates(grouped_translations) do
    Enum.find(grouped_translations, fn({_, translations}) -> length(translations) > 1 end)
  end

  defp build_duplicate_error({_, duplicates}) do
    [last|rest] =
      duplicates
      |> Enum.map(fn(%{po_source: {_, line}}) -> line end)
      |> Enum.sort(&(&1 > &2)) # reverse sort

    lines = rest |> Enum.reverse |> Enum.join(", ")

    reason = "found duplicates of this translation on lines #{lines}"
    {:error, last, reason}
  end
end
