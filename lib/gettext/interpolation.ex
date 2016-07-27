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
