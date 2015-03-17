defmodule Gettext.PO.Parser do
  @moduledoc false

  defmodule Translation do
    @moduledoc false
    defstruct [:msgid, :msgstr]
  end

  @doc """
  Parses a list of tokens into a list of translations.
  """
  def parse(tokens) do
    case :gettext_po_parser.parse(tokens) do
      {:ok, translations} -> Enum.map(translations, &to_struct/1)
      {:error, _}         -> raise "syntax error"
    end
  end

  defp to_struct(translation) do
    Map.put(translation, :__struct__, Translation)
  end
end
