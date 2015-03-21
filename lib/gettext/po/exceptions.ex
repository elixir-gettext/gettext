defmodule Gettext.PO.SyntaxError do
  defexception [:message]

  def exception(opts) do
    line    = Keyword.fetch!(opts, :line)
    message = Keyword.fetch!(opts, :message)

    msg = "invalid syntax on line #{line}: #{message}"
    %__MODULE__{message: msg}
  end
end
