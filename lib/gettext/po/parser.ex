defmodule Gettext.PO.Parser do
  @moduledoc false

  alias Gettext.PO.Translation
  alias Gettext.PO.SyntaxError

  @doc """
  Parses a list of tokens into a list of translations.
  """
  @spec parse([Gettext.PO.Tokenizer.token]) :: [Translation.t]
  def parse(tokens) do
    case :gettext_po_parser.parse(tokens) do
      {:ok, translations} -> Enum.map(translations, &to_struct/1)
      {:error, reason}    -> parse_error_reason_and_raise!(reason)
    end
  end

  @spec to_struct(Map.t) :: Translation.t
  defp to_struct(translation) do
    Map.put(translation, :__struct__, Translation)
  end

  @spec parse_error_reason_and_raise!(term) :: no_return
  defp parse_error_reason_and_raise!({line, _module, reason}) do
    raise SyntaxError, line: line, message: inspect(reason)
  end
end
