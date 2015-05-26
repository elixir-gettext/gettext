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
    try do
      Enum.reduce translations, HashDict.new, fn(t, acc) ->
        id = translation_id(t)
        line = t.po_source_line

        if old_line = Dict.get(acc, id) do
          throw({old_line, line})
        else
          Dict.put_new(acc, id, line)
        end
      end

      :ok
    catch
      {old_line, line} ->
        {:error, line, "found duplicate of this translation on line #{old_line}"}
    end
  end

  defp translation_id(%Translation{msgid: id}),
    do: id
  defp translation_id(%PluralTranslation{msgid: id, msgid_plural: idp}),
    do: {id, idp}
end
