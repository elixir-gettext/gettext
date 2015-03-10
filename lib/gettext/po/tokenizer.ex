defmodule Gettext.PO.Tokenizer do
  @moduledoc false

  # This module is responsible for turning a chunk of text (a string) into a
  # list of tokens. For what "token" means, see the docs for `tokenize/1`.

  alias Gettext.PO.SyntaxError
  alias Gettext.PO.TokenMissingError

  @keywords ~w(msgid msgstr)

  @whitespace [?\n, ?\t, ?\r, ?\s]
  @whitespace_no_nl [?\t, ?\r, ?\s]
  @escapable_chars [?", ?n, ?t, ?\\]

  @doc """
  Converts a string into a list of tokens.

  A "token" is a three elements tuple formed by:

    * the type of the token (an atom like `:keyword` or `:string`)
    * the line the token is at
    * the value of the token

  Some examples of tokens are:

    * `{:keyword, 33, :msgid}`
    * `{:string, 6, "foo"}`

  """
  def tokenize(str) do
    tokenize_line(str, 1, [])
  end

  # Converts the first line in `str` into a list of tokens and then moves on to
  # the next line.
  defp tokenize_line(str, line, acc)

  # Go to the next line.
  defp tokenize_line(<<?\n, rest :: binary>>, line, acc) do
    tokenize_line(rest, line + 1, acc)
  end

  # Skip whitespace.
  defp tokenize_line(<<char, rest :: binary>>, line, acc) when char in @whitespace_no_nl do
    tokenize_line(rest, line, acc)
  end

  # Keywords.
  for kw <- @keywords do
    defp tokenize_line(unquote(kw) <> <<char, rest :: binary>>, line, acc)
        when char in unquote(@whitespace) do
      acc = [{:keyword, line, unquote(String.to_atom(kw))}|acc]
      tokenize_line(rest, line, acc)
    end

    defp tokenize_line(unquote(kw) <> _rest, line, _acc) do
      raise(SyntaxError, message: "no space after '#{unquote(kw)}'", line: line)
    end
  end

  # String start.
  defp tokenize_line(<<?", rest :: binary>>, line, acc) do
    {str, rest} = tokenize_string(rest, line, "")
    tokenize_line(rest, line, [{:string, line, str}|acc])
  end

  # End of file.
  defp tokenize_line(<<>>, _line, acc) do
    Enum.reverse acc
  end

  # Parses the double-quotes-delimited string `str` into a single `{:string,
  # line, contents}` token. Note that `str` doesn't start with a double quote
  # (since that was needed to identify the start of a string). Returns a tuple
  # with the contents of the string and the rest of the original `str` (note
  # that the rest  of the original string doesn't include the closing double
  # quote).
  defp tokenize_string(str, line, acc)

  defp tokenize_string(<<?", rest :: binary>>, _line, acc),
    do: {acc, rest}
  defp tokenize_string(<<?\\, ?n, rest :: binary>>, line, acc),
    do: tokenize_string(rest, line, <<acc :: binary, ?\n>>)
  defp tokenize_string(<<?\\, ?t, rest :: binary>>, line, acc),
    do: tokenize_string(rest, line, <<acc :: binary, ?\t>>)
  defp tokenize_string(<<?\\, ?", rest :: binary>>, line, acc),
    do: tokenize_string(rest, line, <<acc :: binary, ?">>)
  defp tokenize_string(<<?\\, ?\\, rest :: binary>>, line, acc),
    do: tokenize_string(rest, line, <<acc :: binary, ?\\>>)
  defp tokenize_string(<<?\n, _rest :: binary>>, line, _acc),
    do: raise(SyntaxError, line: line, message: "newline in string")
  defp tokenize_string(<<char, rest :: binary>>, line, acc),
    do: tokenize_string(rest, line, <<acc :: binary, char>>)
  defp tokenize_string(<<>>, line, _acc),
    do: raise(TokenMissingError, line: line, token: ~s("))
end
