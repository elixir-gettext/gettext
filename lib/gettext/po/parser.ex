defmodule Gettext.PO.Parser do
  @moduledoc false

  alias Gettext.PO.Translation
  alias Gettext.PO.SyntaxError

  @doc """
  Parses a list of tokens into a list of translations.
  """
  def parse(tokens) do
    case :gettext_po_parser.parse(tokens) do
      {:ok, translations} -> Enum.map(translations, &to_struct/1)
      {:error, reason}    -> parse_error_reason_and_raise!(reason)
    end
  end

  defp to_struct(translation) do
    Map.put(translation, :__struct__, Translation)
  end

  defp parse_error_reason_and_raise!({line, _module, reason}) do
    raise SyntaxError, line: line, message: inspect(reason)
  end
end
