defmodule Gettext.PO.Parser do
  @moduledoc false

  alias Gettext.PO.Translations
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  @doc """
  Parses a list of tokens into a list of translations.
  """
  @spec parse([Gettext.PO.Tokenizer.token()]) ::
          {:ok, [binary], [Gettext.PO.translation()]} | Gettext.PO.parse_error()
  def parse(tokens) when is_list(tokens) do
    case :gettext_po_parser.parse(tokens) do
      {:ok, translations} ->
        parse_yecc_result(translations)

      {:error, _reason} = error ->
        parse_error(error)
    end
  end

  defp parse_yecc_result(translations) do
    translations = Enum.map(translations, &to_struct/1)

    with :ok <- check_for_duplicates(translations) do
      {top_comments, headers, translations} = extract_top_comments_and_headers(translations)
      {:ok, top_comments, headers, translations}
    end
  end

  defp to_struct({:translation, translation}) do
    struct(Translation, translation)
    |> extract_references()
    |> extract_extracted_comments()
    |> extract_flags()
  end

  defp to_struct({:plural_translation, translation}) do
    struct(PluralTranslation, translation)
    |> extract_references()
    |> extract_extracted_comments()
    |> extract_flags()
  end

  defp parse_error({:error, {line, _module, reason}}) do
    {:error, line, parse_error_reason(reason)}
  end

  defp extract_references(%{__struct__: _, comments: comments} = translation) do
    {reference_comments, other_comments} = Enum.split_with(comments, &match?("#:" <> _, &1))

    references =
      reference_comments
      |> Enum.reject(fn "#:" <> comm -> String.trim(comm) == "" end)
      |> Enum.flat_map(&parse_references/1)

    %{translation | references: references, comments: other_comments}
  end

  defp parse_references("#:" <> comment) do
    # Steps:
    #   * after trimming, we remain with "21 foo.ex"
    #   * [file, line, file, line...]
    #   * [[file, line], [file, line], ...]
    #   * [{file, line}, {file, line}, ...]
    comment
    |> String.trim()
    |> String.split(":")
    |> Enum.flat_map(&parse_reference_part/1)
    |> enum_chunk_every(2)
    |> Enum.map(&List.to_tuple/1)
  end

  defp parse_reference_part(part) do
    case Integer.parse(part) do
      {next_line_no, ""} ->
        # last line number
        [next_line_no]

      {next_line_no, filename} ->
        [next_line_no, String.trim_leading(filename)]

      :error ->
        # first filename
        [part]
    end
  end

  defp extract_extracted_comments(%{__struct__: _, comments: comments} = translation) do
    {extracted_comments, other_comments} = Enum.split_with(comments, &match?("#." <> _, &1))

    extracted_comments =
      Enum.reject(extracted_comments, fn "#." <> comm -> String.trim(comm) == "" end)

    %{translation | extracted_comments: extracted_comments, comments: other_comments}
  end

  defp extract_flags(%{__struct__: _, comments: comments} = translation) do
    {flag_comments, other_comments} = Enum.split_with(comments, &match?("#," <> _, &1))
    %{translation | flags: parse_flags(flag_comments), comments: other_comments}
  end

  defp parse_flags(flag_comments) do
    flag_comments
    |> Stream.map(fn "#," <> content -> content end)
    |> Stream.flat_map(&String.split(&1, ~r/[,\s]+/, trim: true))
    |> MapSet.new()
  end

  # If the first translation has an empty msgid, it's assumed to represent
  # headers. Headers will be in the msgstr of this "fake" translation, one on
  # each line. For now, we'll just separate those lines in order to get a list
  # of headers.
  defp extract_top_comments_and_headers([%Translation{msgid: id, msgstr: headers} = t | rest])
       when id == "" or id == [""] do
    {t.comments, headers, rest}
  end

  defp extract_top_comments_and_headers(translations) do
    {[], [], translations}
  end

  defp check_for_duplicates(translations) do
    check_for_duplicates(translations, %{})
  end

  defp check_for_duplicates([t | translations], existing) do
    key = Translations.key(t)

    case Map.fetch(existing, key) do
      {:ok, old_line} ->
        build_duplicated_error(t, old_line)

      :error ->
        check_for_duplicates(translations, Map.put(existing, key, t.po_source_line))
    end
  end

  defp check_for_duplicates([], _existing) do
    :ok
  end

  defp build_duplicated_error(%Translation{} = t, old_line) do
    id = IO.iodata_to_binary(t.msgid)
    {:error, t.po_source_line, "found duplicate on line #{old_line} for msgid: '#{id}'"}
  end

  defp build_duplicated_error(%PluralTranslation{} = t, old_line) do
    id = IO.iodata_to_binary(t.msgid)
    idp = IO.iodata_to_binary(t.msgid_plural)
    msg = "found duplicate on line #{old_line} for msgid: '#{id}' and msgid_plural: '#{idp}'"
    {:error, t.po_source_line, msg}
  end

  # We need to explicitly parse the error reason that yecc spits out because a
  # `{type, line, token}` token is printed as the Erlang term in the error (by
  # yecc). So, for example, if a token has a binary value then yecc will return
  # something like:
  #
  #     syntax error before: <<"my token">>
  #
  # which is not what we want, as we want the term to be printed as an Elixir
  # term. While this is ugly, it's necessary (as yecc is not very extensible)
  # and is what Elixir itself does
  # (https://github.com/elixir-lang/elixir/blob/b80651/lib/elixir/src/elixir_errors.erl#L51-L103).
  defp parse_error_reason([error, token]) do
    IO.chardata_to_string(parse_error_reason(error, to_string(token)))
  end

  defp parse_error_reason('syntax error before: ' = prefix, "<<" <> rest),
    do: [prefix, binary_part(rest, 0, byte_size(rest) - 2)]

  defp parse_error_reason(error, token), do: [error, token]

  # TODO: remove once we depend on Elixir 1.5 and on.
  chunk_every = if function_exported?(Enum, :chunk_every, 2), do: :chunk_every, else: :chunk
  defp enum_chunk_every(enum, n), do: apply(Enum, unquote(chunk_every), [enum, n])
end
