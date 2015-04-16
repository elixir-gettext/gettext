defmodule Gettext.Interpolation do
  @interpolation_regex ~r/
    (?<left>)  # Start, available through :left
    %{         # Literal '%{'
      [^}]+    # One or more non-} characters
    }          # Literal '}'
    (?<right>) # End, available through :right
  /x

  defmodule BadInterpolationError do
    defexception [:message]

    def exception(opts) do
      str = Keyword.fetch!(opts, :interpolation)
      msg = "invalid interpolation: '#{str}'"
      %__MODULE__{message: msg}
    end
  end

  def to_interpolatable(str) do
    split = Regex.split(@interpolation_regex, str, on: [:left, :right], trim: true)

    Enum.map split, fn
      "%{" <> rest -> rest |> String.rstrip(?}) |> String.to_atom
      segment      -> segment
    end
  end

  def missing_interpolation_keys(bindings, required) do
    present = Dict.keys(bindings)
    missing = required -- present
    "missing interpolation keys: " <> Enum.map_join(missing, ", ", &to_string/1)
  end

  def keys(str) do
    str
    |> to_interpolatable
    |> Enum.filter(&is_atom/1)
  end

  def interpolate(str, bindings) do
    try do
      s = Enum.map_join to_interpolatable(str), "", fn
        key when is_atom(key) -> Dict.fetch!(bindings, key)
        other                 -> other
      end
      {:ok, s}
    rescue
      KeyError ->
        required = keys(str)
        {:error, missing_interpolation_keys(bindings, required)}
    end
  end
end
