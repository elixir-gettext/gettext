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
  Interpolate an interpolatable with the given bindings.

  This function takes an interpolatable list returned from `to_interpolatable/1` and bindings
  and returns the interpolated string. If it encounters an atom that should be interpolated
  but is missing from the bindings, it will call the provided `handle_missing_binding` function.
  The callback will be called with the missing binding, the original string and the locale.
  See also the default implementation in `Gettext`.

  ## Examples

      iex> msgid = "Hello %{name}, you have %{count} unread messages"
      iex> interpolatable = Gettext.Interpolation.to_interpolatable(msgid)
      iex> good_bindings = %{name: "José", count: 3}
      iex> Gettext.Interpolation.interpolate(interpolatable, :ok, good_bindings)
      {:ok, "Hello José, you have 3 unread messages"}
      iex> bad_bindings = %{name: "José"}
      iex> Gettext.Interpolation.interpolate(interpolatable, :ok, bad_bindings)
      {:missing_bindings, "Hello José, you have %{count} unread messages", [:count]}

  """
  def interpolate(interpolatable, key, bindings) do
    interpolate(interpolatable, key, bindings, [], [])
  end

  defp interpolate([string | segments], key, bindings, strings, missing) when is_binary(string) do
    interpolate(segments, key, bindings, [string | strings], missing)
  end
  defp interpolate([atom | segments], key, bindings, strings, missing) when is_atom(atom) do
    case bindings do
      %{^atom => value} ->
        interpolate(segments, key, bindings, [to_string(value) | strings], missing)
      %{} ->
        interpolate(segments, key, bindings, ["%{" <> Atom.to_string(atom) <> "}" | strings], [atom | missing])
    end
  end
  defp interpolate([], key, _bindings, strings, []) do
    {key, IO.iodata_to_binary(Enum.reverse(strings))}
  end
  defp interpolate([], _key, _bindings, strings, missing) do
    {:missing_bindings, IO.iodata_to_binary(Enum.reverse(strings)), missing}
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

      iex> Gettext.Interpolation.keys(["Hello ", :name, "! Goodbye", :name])
      [:name]

  """
  @spec keys(binary | [atom]) :: [atom]

  def keys(str) when is_binary(str),
    do: str |> to_interpolatable |> keys
  def keys(segments) when is_list(segments),
    do: Enum.filter(segments, &is_atom/1) |> Enum.uniq
end
