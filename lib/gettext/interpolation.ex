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

  This function takes an interpolatable list (like the ones returned by
  `to_interpolatable/1`) and some bindings and returns an `{:ok,
  interpolated_string}` tuple ` if interpolation is successful. If it encounters
  an atom in `interpolatable` that is missing from `bindings`, it returns
  `{:missing_bindings, incomplete_string, missing_bindings}` where
  `incomplete_string` is the string with only the present bindings interpolated
  and `missing_bindings` is a list of atoms representing bindings that are in
  `interpolatable` but not in `bindings`.

  ## Examples

      iex> msgid = "Hello %{name}, you have %{count} unread messages"
      iex> interpolatable = Gettext.Interpolation.to_interpolatable(msgid)
      iex> good_bindings = %{name: "José", count: 3}
      iex> Gettext.Interpolation.interpolate(interpolatable, good_bindings)
      {:ok, "Hello José, you have 3 unread messages"}
      iex> Gettext.Interpolation.interpolate(interpolatable, %{name: "José"})
      {:missing_bindings, "Hello José, you have %{count} unread messages", [:count]}

  """
  def interpolate(interpolatable, bindings)
      when is_list(interpolatable) and is_map(bindings) do
    interpolate(interpolatable, bindings, [], [])
  end

  defp interpolate([string | segments], bindings, strings, missing) when is_binary(string) do
    interpolate(segments, bindings, [string | strings], missing)
  end
  defp interpolate([atom | segments], bindings, strings, missing) when is_atom(atom) do
    case bindings do
      %{^atom => value} ->
        interpolate(segments, bindings, [to_string(value) | strings], missing)
      %{} ->
        interpolate(segments, bindings, ["%{" <> Atom.to_string(atom) <> "}" | strings], [atom | missing])
    end
  end
  defp interpolate([], _bindings, strings, []) do
    {:ok, IO.iodata_to_binary(Enum.reverse(strings))}
  end
  defp interpolate([], _bindings, strings, missing) do
    missing = missing |> Enum.reverse |> Enum.uniq
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
