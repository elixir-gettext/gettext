defmodule Gettext.PO.SyntaxError do
  defexception [:message]

  def exception(opts) do
    line    = Keyword.fetch!(opts, :line)
    message = Keyword.fetch!(opts, :message)

    msg = "invalid syntax on line #{line}: #{message}"
    %__MODULE__{message: msg}
  end
end

defmodule Gettext.PO.TokenMissingError do
  defexception [:message]

  def exception(opts) do
    line    = Keyword.fetch!(opts, :line)
    token = Keyword.fetch!(opts, :token)

    msg = "missing token #{token} on line #{line}"
    %__MODULE__{message: msg}
  end
end
