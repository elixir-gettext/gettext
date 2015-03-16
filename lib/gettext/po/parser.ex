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
      {:ok, translations} -> Enum.map(translations, &convert_to_struct/1)
      {:error, _}         -> raise "syntax error"
    end
  end

  defp convert_to_struct({:translation, {{:msgid, _}, msgid}, {{:msgstr, _}, msgstr}}) do
    %Translation{msgid: concat(msgid), msgstr: concat(msgstr)}
  end

  defp concat(strings) do
    Enum.reduce strings, "", fn({:string, _line, string}, acc) ->
      acc <> string
    end
  end
end
