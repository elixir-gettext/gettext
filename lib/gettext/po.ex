defmodule Gettext.PO do
  alias Gettext.PO.Tokenizer
  alias Gettext.PO.Parser

  @spec parse_string(binary) :: {:ok, Gettext.PO.Translation.t}
  def parse_string(str) do
    case Tokenizer.tokenize(str) do
      {:error, _line, _reason} = error ->
        error
      {:ok, tokens} ->
        Parser.parse(tokens)
    end
  end

  @spec parse_string(Path.t) :: {:ok, Gettext.PO.Translation.t}
  def parse_file(path) do
    case File.read(path) do
      {:ok, contents} ->
        parse_string(contents)
      {:error, _reason} = error ->
        error
    end
  end
end
