defmodule Gettext.Interpolation do
  @moduledoc """
  Provides facilities for working with interpolations.
  """

  @interpolation_regex ~r/
    (?<left>)  # Start, available through :left
    %{         # Literal '%{'
      [^}]+    # One or more non-} characters
    }          # Literal '}'
    (?<right>) # End, available through :right
  /x

  @doc """
  Extracts interpolations from a given string.

  This function extracts all interpolations in the form `%{interpolation}`
  contained inside `str`, converts them to atoms and then returns a list of
  string and interpolation keys.

  ## Examples

      iex> to_interpolatable("Hello %{name}, you have %{count} unread messages")
      ["Hello ", :name, ", you have ", :count, " unread messages"]

  """
  @spec to_interpolatable(binary) :: [binary | atom]
  def to_interpolatable(str) do
    split = Regex.split(@interpolation_regex, str, on: [:left, :right], trim: true)

    Enum.map split, fn
      "%{" <> rest -> rest |> String.rstrip(?}) |> String.to_atom
      segment      -> segment
    end
  end

  @doc """
  Tells which `required` keys are missing in `bindings`.

  Returns an error message which tells which keys in `required` don't appear in
  `bindings`.

  ## Examples

      iex> missing_interpolation_keys(%{foo: 1}, [:foo, :bar, :baz]
      "missing interpolation keys: bar, baz"

  """
  @spec missing_interpolation_keys(Dict.t, [atom]) :: binary
  def missing_interpolation_keys(bindings, required) do
    present = Dict.keys(bindings)
    missing = required -- present
    "missing interpolation keys: " <> Enum.map_join(missing, ", ", &to_string/1)
  end

  @doc """
  Returns all the interpolation keys contained in `str`.

  This function returns a list of all the interpolation keys (patterns in the
  form `%{interpolation}`) contained in `str`.

  ## Examples

      iex> keys("Hey %{name}, I'm %{other_name}")
      [:name, :other_name]

  """
  @spec keys(binary) :: [atom]
  def keys(str) do
    str
    |> to_interpolatable
    |> Enum.filter(&is_atom/1)
  end

  @doc """
  Dynimically interpolates `str` with the given `bindings`.

  This function replaces all interpolations (like `%{this}`) inside `str` with
  the keys contained in `bindings`. It returns `{:ok, str}` if all the
  interpolation keys in `str` are present in `bindings`, `{:error, msg}`
  otherwise.

  ## Examples

      iex> interpolate "Hello %{name}", name: "José"
      {:ok, "Hello José"}
      iex> interpolate "%{count} errors", %{name: "Jane"}
      {:error, "missing interpolation keys: count"}

  """
  @spec interpolate(binary, Dict.t) :: {:ok, binary} | {:error, binary}
  def interpolate(str, bindings) do
    keys = keys(str)

    if keys -- Dict.keys(bindings) != [] do
      {:error, missing_interpolation_keys(bindings, keys)}
    else
      interpolated = Enum.map_join to_interpolatable(str), "", fn
        key when is_atom(key) -> Dict.fetch!(bindings, key)
        other                 -> other
      end
      {:ok, interpolated}
    end
  end
end
