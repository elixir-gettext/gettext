defmodule Gettext.PO.Parser do
  @moduledoc false

  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  @typep headers :: [binary]

  @doc """
  Parses a list of tokens into a list of translations.
  """
  @spec parse([Gettext.PO.Tokenizer.token]) ::
    {:ok, headers, [Translation.t]} | {:error, pos_integer, binary}
  def parse(tokens) do
    case :gettext_po_parser.parse(tokens) do
      {:ok, translations} ->
        {headers, translations} =
          translations
          |> Enum.map(&to_struct/1)
          |> extract_headers()
        {:ok, headers, translations}
      {:error, _reason} = error ->
        parse_error(error)
    end
  end

  @spec to_struct(Map.t) :: Translation.t
  defp to_struct({:translation, translation}),
    do: struct(Translation, translation) |> extract_references()
  defp to_struct({:plural_translation, translation}),
    do: struct(PluralTranslation, translation) |> extract_references()

  @spec parse_error({:error, term}) :: {:error, pos_integer, binary}
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
  defp extract_headers([%Translation{msgid: ""} = t|rest]),
    do: {String.split(t.msgstr, "\n", trim: true), rest}
  defp extract_headers(translations),
    do: {[], translations}
end
