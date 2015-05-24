defmodule Gettext.Interpolation do
  @moduledoc false

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

      iex> Gettext.Interpolation.to_interpolatable("Hello %{name}, you have %{count} unread messages")
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

      iex> Gettext.Interpolation.missing_interpolation_keys %{foo: 1}, [:foo, :bar, :baz]
      "missing interpolation keys: bar, baz"

  """
  @spec missing_interpolation_keys(%{}, [atom]) :: binary
  def missing_interpolation_keys(bindings, required) do
    present = Dict.keys(bindings)
    missing = required -- present
    "missing interpolation keys: " <> Enum.map_join(missing, ", ", &to_string/1)
  end

  @doc """
  Returns all the interpolation keys contained in the given string or list of
  segments.

  This function returns a list of all the interpolation keys (patterns in the
  form `%{interpolation}`) contained in its argument.

  If the argument is a segment list, i.e., a list of strings and atoms where
  atoms represent interpolation keys, then only the atoms in the list are
  returned.

  ## Examples

      iex> Gettext.Interpolation.keys("Hey %{name}, I'm %{other_name}")
      [:name, :other_name]

      iex> Gettext.Interpolation.keys(["Hello ", :name, "!"])
      [:name]

  """
  @spec keys(binary | [atom]) :: [atom]

  def keys(str) when is_binary(str),
    do: str |> to_interpolatable |> Enum.filter(&is_atom/1)
  def keys(segments) when is_list(segments),
    do: Enum.filter(segments, &is_atom/1)

  @doc """
  Dynimically interpolates `str` with the given `bindings`.

  This function replaces all interpolations (like `%{this}`) inside `str` with
  the keys contained in `bindings`. It returns `{:ok, str}` if all the
  interpolation keys in `str` are present in `bindings`, `{:error, msg}`
  otherwise.

  ## Examples

      iex> Gettext.Interpolation.interpolate "Hello %{name}", %{name: "José"}
      {:ok, "Hello José"}
      iex> Gettext.Interpolation.interpolate "%{count} errors", %{name: "Jane"}
      {:error, "missing interpolation keys: count"}

  """
  @spec interpolate(binary, %{}) :: {:ok, binary} | {:error, binary}
  def interpolate(str, bindings) do
    segments = to_interpolatable(str)
    keys     = keys(segments)

    if keys -- Map.keys(bindings) != [] do
      {:error, missing_interpolation_keys(bindings, keys)}
    else
      interpolated = Enum.map_join segments, "", fn
        key when is_atom(key) -> Map.fetch!(bindings, key)
        other                 -> other
      end
      {:ok, interpolated}
    end
  end
end
