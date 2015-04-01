defmodule Gettext.PO.SyntaxError do
  defexception [:message]

  def exception(opts) do
    line   = Keyword.fetch!(opts, :line)
    reason = Keyword.fetch!(opts, :reason)

    msg =
      if file = opts[:file] do
        file = Path.basename(file)
        "#{file}:#{line}: #{reason}"
      else
        "#{line}: #{reason}"
      end

    %__MODULE__{message: msg}
  end
end
