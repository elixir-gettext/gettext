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
    do: struct(Translation, translation) |> extract_references() |> set_fuzziness()
  defp to_struct({:plural_translation, translation}),
    do: struct(PluralTranslation, translation) |> extract_references() |> set_fuzziness()

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

  defp set_fuzziness(%{__struct__: _, comments: comments} = translation) do
    flags = Enum.flat_map comments, fn
      "#," <> flags -> String.split(flags, ~r/\s+/, trim: true)
      _             -> []
    end

    %{translation | fuzzy: Enum.member?(flags, "fuzzy")}
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
        if old_line = Dict.get(acc, id) do
          throw({t, old_line})
        else
          Dict.put_new(acc, id, t.po_source_line)
        end
      end

      :ok
    catch
      {t, old_line} ->
        build_duplicated_error(t, old_line)
    end
  end

  defp translation_id(%Translation{msgid: id}),
    do: id
  defp translation_id(%PluralTranslation{msgid: id, msgid_plural: idp}),
    do: {id, idp}

  defp build_duplicated_error(%Translation{} = t, old_line) do
    id = IO.iodata_to_binary(t.msgid)
    {:error, t.po_source_line, "found duplicate on line #{old_line} for msgid: '#{id}'"}
  end

  defp build_duplicated_error(%PluralTranslation{} = t, old_line) do
    id  = IO.iodata_to_binary(t.msgid)
    idp = IO.iodata_to_binary(t.msgid_plural)
    msg = "found duplicate on line #{old_line} for msgid: '#{id}' and msgid_plural: '#{idp}'"
    {:error, t.po_source_line, msg}
  end
end
