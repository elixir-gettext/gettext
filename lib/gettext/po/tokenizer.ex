defmodule Gettext.PO.Tokenizer do
  @moduledoc false

  # This module is responsible for turning a chunk of text (a string) into a
  # list of tokens. For what "token" means, see the docs for `tokenize/1`.

  @type token ::
    {:str, pos_integer, binary} |
    {:msgid, pos_integer} |
    {:msgstr, pos_integer}

  # In this list of keywords *the order matters*. If, for example, `msgid` was
  # the first one and `msgid_plural` was the second one, an error would be
  # raised with strings like "msgid_plural " because the tokenizer will complain
  # about a space missing after the keyword `msgid`. If we give precedence to
  # `msgid_plural`, however, it works. The order matters because a function
  # clause is generated for each keyword.
  @keywords ~w(
    msgid_plural
    msgid
    msgstr
  )

  @whitespace [?\n, ?\t, ?\r, ?\s]
  @whitespace_no_nl [?\t, ?\r, ?\s]
  @escapable_chars [?", ?n, ?t, ?\\]

  @doc """
  Converts a string into a list of tokens.

  A "token" is a tuple formed by:

    * the `:str` tag or a keyword tag (like `:msgid`)
    * the line the token is at
    * the value of the token if the token has a value (for example, a `:str`
      token will have the contents of the string as a value)

  Some examples of tokens are:

    * `{:msgid, 33}`
    * `{:str, 6, "foo"}`

  """
  @spec tokenize(binary) :: {:ok, [token]} | {:error, pos_integer, binary}
  def tokenize(str) do
    tokenize_line(str, 1, [])
  end

  # Converts the first line in `str` into a list of tokens and then moves on to
  # the next line.
  @spec tokenize_line(binary, pos_integer, [token]) ::
    {:ok, [token]} | {:error, pos_integer, binary}
  defp tokenize_line(str, line, acc)

  # End of file.
  defp tokenize_line(<<>>, _line, acc) do
    {:ok, Enum.reverse(acc)}
  end

  # Go to the next line.
  defp tokenize_line(<<?\n, rest :: binary>>, line, acc) do
    tokenize_line(rest, line + 1, acc)
  end

  # Skip whitespace.
  defp tokenize_line(<<char, rest :: binary>>, line, acc)
      when char in @whitespace_no_nl do
    tokenize_line(rest, line, acc)
  end

  # Comments.
  defp tokenize_line(<<?#, rest :: binary>>, line, acc) do
    {_comment_contents, rest} = to_eol_or_eof(rest, "")
    tokenize_line(rest, line, acc)
  end

  # Keywords.
  for kw <- @keywords do
    defp tokenize_line(unquote(kw) <> <<char, rest :: binary>>, line, acc)
        when char in @whitespace do
      acc = [{unquote(String.to_atom(kw)), line}|acc]
      tokenize_line(rest, line, acc)
    end

    defp tokenize_line(unquote(kw) <> _rest, line, _acc) do
      {:error, line, "no space after '#{unquote(kw)}'"}
    end
  end

  # String start.
  defp tokenize_line(<<?", rest :: binary>>, line, acc) do
    case tokenize_string(rest, line, "") do
      {:ok, token, rest} ->
        tokenize_line(rest, line, [token|acc])
      {:error, reason} ->
        {:error, line, reason}
    end
  end

  # Unknown keyword.
  # An unknown keyword is assumed at this point. In order to generate a nice and
  # informative error message, the whole keyword (up to the first non-word
  # character) is retrieved with `next_word/1` instead of just the first
  # character.
  defp tokenize_line(binary, line, _acc) when is_binary(binary) do
    {:error, line, "unknown keyword '#{next_word(binary)}'"}
  end

  # Parses the double-quotes-delimited string `str` into a single `{:str,
  # line, contents}` token. Note that `str` doesn't start with a double quote
  # (since that was needed to identify the start of a string). Returns a tuple
  # with the contents of the string and the rest of the original `str` (note
  # that the rest of the original string doesn't include the closing double
  # quote).
  @spec tokenize_string(binary, pos_integer, binary) ::
    {:ok, token, binary} | {:error, binary}
  defp tokenize_string(str, line, acc)

  defp tokenize_string(<<?", rest :: binary>>, line, acc),
    do: {:ok, {:str, line, acc}, rest}
  defp tokenize_string(<<?\\, char, rest :: binary>>, line, acc)
    when char in @escapable_chars,
    do: tokenize_string(rest, line, <<acc :: binary, escape_char(char)>>)
  defp tokenize_string(<<?\\, _char, _rest :: binary>>, _line, _acc),
    do: {:error, "unsupported escape code"}
  defp tokenize_string(<<?\n, _rest :: binary>>, _line, _acc),
    do: {:error, "newline in string"}
  defp tokenize_string(<<char, rest :: binary>>, line, acc),
    do: tokenize_string(rest, line, <<acc :: binary, char>>)
  defp tokenize_string(<<>>, _line, _acc),
    do: {:error, "missing token \""}

  @spec escape_char(char) :: char
  defp escape_char(?n), do: ?\n
  defp escape_char(?t), do: ?\t
  defp escape_char(?r), do: ?\r
  defp escape_char(?"), do: ?"
  defp escape_char(?\\), do: ?\\

  @spec to_eol_or_eof(binary, binary) :: {binary, binary}
  defp to_eol_or_eof(<<?\n, _ :: binary>> = rest, acc),
    do: {acc, rest}
  defp to_eol_or_eof(<<>>, acc),
    do: {acc, ""}
  defp to_eol_or_eof(<<char, rest :: binary>>, acc),
    do: to_eol_or_eof(rest, <<acc :: binary, char>>)

  @spec next_word(binary) :: binary
  defp next_word(binary), do: Regex.run(~r/\w+/u, binary)
end
