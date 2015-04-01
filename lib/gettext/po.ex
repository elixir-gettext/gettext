defmodule Gettext.PO do
  alias Gettext.PO.Tokenizer
  alias Gettext.PO.Parser
  alias Gettext.PO.SyntaxError

  @typep line   :: pos_integer
  @typep parsed :: [Gettext.PO.Translation.t]

  @spec parse_string(binary) :: {:ok, parsed} | {:error, line, binary}
  def parse_string(str) do
    case Tokenizer.tokenize(str) do
      {:error, _line, _reason} = error ->
        error
      {:ok, tokens} ->
        Parser.parse(tokens)
    end
  end

  @spec parse_string!(binary) :: parsed
  def parse_string!(str) do
    case parse_string(str) do
      {:ok, parsed} ->
        parsed
      {:error, line, reason} ->
        raise SyntaxError, line: line, reason: reason
    end
  end

  @spec parse_file(Path.t) ::
    {:ok, parsed}
    | {:error, line, binary}
    | {:error, atom}
  def parse_file(path) do
    case File.read(path) do
      {:ok, contents} ->
        parse_string(contents)
      {:error, _reason} = error ->
        error
    end
  end

  @spec parse_file!(Path.t) :: parsed
  def parse_file!(path) do
    case parse_file(path) do
      {:ok, parsed} ->
        parsed
      {:error, reason} ->
        File.read!(path)
      {:error, line, reason} ->
        raise SyntaxError, file: path, line: line, reason: reason
    end
  end
end
