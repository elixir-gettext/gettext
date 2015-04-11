defmodule Gettext.PO.Parser do
  @moduledoc false

  alias Gettext.PO.Translation

  @doc """
  Parses a list of tokens into a list of translations.
  """
  @spec parse([Gettext.PO.Tokenizer.token]) ::
    {:ok, [Translation.t]} | {:error, pos_integer, binary}
  def parse(tokens) do
    case :gettext_po_parser.parse(tokens) do
      {:ok, translations} ->
        {:ok, Enum.map(translations, &to_struct/1)}
      {:error, _reason} = error ->
        parse_error(error)
    end
  end

  @spec to_struct(Map.t) :: Translation.t
  defp to_struct(translation) do
    struct(Translation, translation)
  end

  @spec parse_error({:error, term}) :: {:error, pos_integer, binary}
  defp parse_error({:error, {line, _module, reason}}) do
    {:error, line, IO.chardata_to_string(reason)}
  end
end
