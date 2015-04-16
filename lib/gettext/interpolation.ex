defmodule Gettext.Interpolation do
  defmodule BadInterpolationError do
    defexception [:message]

    def exception(opts) do
      str = Keyword.fetch!(opts, :interpolation)
      msg = "invalid interpolation: '#{str}'"
      %__MODULE__{message: msg}
    end
  end

  def missing_interpolation_keys(bindings, required) do
    present = Dict.keys(bindings)
    missing = required -- present
    "missing interpolation keys: " <> Enum.map_join(missing, ", ", &to_string/1)
  end

  def interpolate(str, bindings) do
    try do
      s = ~r/(?<head>)%{[^}]+}(?<tail>)/
      |> Regex.split(str, on: [:head, :tail])
      |> Enum.map_join("", fn
        "%{" <> rest ->
          key = rest |> String.rstrip(?}) |> String.to_atom
          Dict.fetch!(bindings, key)
        other ->
          other
      end)
      {:ok, s}
    rescue
      KeyError ->
        required =
          Regex.scan(~r/%{([^}]+)}/, str)
          |> Enum.map(fn [_, b] -> String.to_atom(b) end)
        {:error, missing_interpolation_keys(bindings, required)}
    end
  end
end
