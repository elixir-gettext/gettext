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

      iex> interpolatable = ["Hello ", :name, ", you have ", :count, " unread messages"]
      iex> msgid = "Hello %{name}, you have %{count} unread messages"
      iex> bindings = %{ :name => "José", :count => 3 }
      iex> locale = "en_GB"
      iex> handler = fn(binding, _str, _locale) -> Atom.to_string(binding) end
      iex> Gettext.Interpolation.interpolate(interpolatable, bindings, msgid, locale, handler)
      "Hello José, you have 3 unread messages"

  """
  def interpolate(interpolatable, bindings, str, locale, handle_missing_binding) do
    Enum.map_join(interpolatable, "", fn
      segment when is_atom(segment) -> Map.get_lazy(bindings, segment, fn -> handle_missing_binding.(segment, str, locale) end)
      segment                       -> segment
    end)
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
