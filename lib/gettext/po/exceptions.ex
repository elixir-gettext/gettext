defmodule Gettext.PO.SyntaxError do
  defexception [:message]

  def exception(opts) do
    line   = Keyword.fetch!(opts, :line)
    reason = Keyword.fetch!(opts, :reason)

    msg = "#{line}: #{reason}"
    %__MODULE__{message: msg}
  end
end
