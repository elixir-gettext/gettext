defmodule Gettext.Interpolation do
  @moduledoc false

  @type interpolatable :: [String.t() | atom]

  @doc """
  Extracts interpolations from a given string.

  This function extracts all interpolations in the form `%{interpolation}`
  contained inside `str`, converts them to atoms and then returns a list of
  string and interpolation keys.

  ## Examples

      iex> msgid = "Hello %{name}, you have %{count} unread messages"
      iex> Gettext.Interpolation.to_interpolatable(msgid)
      ["Hello ", :name, ", you have ", :count, " unread messages"]

      iex> Gettext.Interpolation.to_interpolatable("Empties %{} stay empty")
      ["Empties %{} stay empty"]

  """
  @spec to_interpolatable(String.t()) :: interpolatable
  def to_interpolatable(string) do
    patterns = %{
      start: :binary.compile_pattern("%{"),
      end: :binary.compile_pattern("}"),
      nested_delimiter: :binary.compile_pattern(":")
    }

    string
    |> to_interpolatable(_current = "", _acc = [], patterns)
    |> Enum.reverse()
  end

  defp to_interpolatable(string, current, acc, patterns) do
    case :binary.split(string, patterns.start) do
      # If we have one element, no %{ was found so this is the final part of the
      # string.
      [rest] ->
        prepend_if_not_empty(current <> rest, acc)

      # If we found a %{ but it's followed by an immediate }, then we just
      # append %{} to the current string and keep going.
      [before, "}" <> rest] ->
        new_current = current <> before <> "%{}"
        to_interpolatable(rest, new_current, acc, patterns)

      # Otherwise, we found the start of a binding.
      [before, binding_and_rest] ->
        case :binary.split(binding_and_rest, patterns.end) do
          # If we don't find the end of this binding, it means we're at a string
          # like "foo %{ no end". In this case we consider no bindings to be
          # there.
          [_] ->
            [current <> string | acc]

          # This is the case where we found a binding, so we put it in the acc
          # and keep going.
          [binding, rest] ->
            binding_and_opt_text = extract_nested_text(binding, patterns.nested_delimiter)
            new_acc = [binding_and_opt_text | prepend_if_not_empty(before, acc)]
            to_interpolatable(rest, "", new_acc, patterns)
        end
    end
  end

  defp prepend_if_not_empty("", list), do: list
  defp prepend_if_not_empty(string, list), do: [string | list]

  defp extract_nested_text(string, nested_delimiter_pattern) do
    case :binary.split(string, nested_delimiter_pattern) do
      # There's no nested text for the binding.
      [binding] ->
        String.to_atom(binding)

      # There's nested text, so put a start and end binding around the text that
      # was found.
      [binding, inner_text] ->
        {String.to_atom(binding), inner_text}
    end
  end

  @doc """
  Interpolate an interpolatable with the given bindings.

  This function takes an interpolatable list (like the ones returned by
  `to_interpolatable/1`) and some bindings and returns an `{:ok,
  interpolated_string}` tuple if interpolation is successful. If it encounters
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
  @spec interpolate(interpolatable, map) ::
          {:ok, String.t()} | {:missing_bindings, String.t(), [atom]}
  def interpolate(interpolatable, bindings)
      when is_list(interpolatable) and is_map(bindings) do
    interpolate(interpolatable, bindings, [], [], [])
  end

  # Next element is a binary, so just put it in the acc and keep going
  defp interpolate([string | segments], bindings, strings, missing, invalid)
       when is_binary(string) do
    interpolate(segments, bindings, [string | strings], missing, invalid)
  end

  # Next element is a simple atom binding, so we need to either replace it or 
  # append a warning if it is not set.
  defp interpolate([atom | segments], bindings, strings, missing, invalid) when is_atom(atom) do
    case bindings do
      %{^atom => value} ->
        interpolate(segments, bindings, [to_string(value) | strings], missing, invalid)

      %{} ->
        strings = ["%{" <> Atom.to_string(atom) <> "}" | strings]
        interpolate(segments, bindings, strings, [atom | missing], invalid)
    end
  end

  # Next element is a binding with nested text, so we need to either replace it or 
  # append a warning if it is not set or not a 1-arity function.
  defp interpolate([{atom, inner} | segments], bindings, strings, missing, invalid)
       when is_atom(atom) and is_binary(inner) do
    case bindings do
      %{^atom => value} when is_function(value, 1) ->
        string = to_string(value.(inner))
        interpolate(segments, bindings, [string | strings], missing, invalid)

      %{^atom => _value} ->
        invalidity = {atom, "Is not a 1-arity function."}
        interpolate(segments, bindings, strings, missing, [invalidity | invalid])

      %{} ->
        strings = ["%{" <> Atom.to_string(atom) <> ":" <> inner <> "}" | strings]
        interpolate(segments, bindings, strings, [atom | missing], invalid)
    end
  end

  # At the end and no warnings. Reverse the iodata and convert to binary
  defp interpolate([], _bindings, strings, [], []) do
    {:ok, IO.iodata_to_binary(Enum.reverse(strings))}
  end

  # At the end, but there were invalid bindings
  defp interpolate([], _bindings, _strings, [], invalid) do
    invalid = invalid |> Enum.reverse() |> Enum.uniq()
    {:invalid_bindings, invalid}
  end

  # At the end, but there were errors
  defp interpolate([], _bindings, strings, missing, _invalid) do
    missing = missing |> Enum.reverse() |> Enum.uniq()
    {:missing_bindings, IO.iodata_to_binary(Enum.reverse(strings)), missing}
  end

  @doc """
  Returns all the interpolation keys contained in the given string or list of
  segments.

  This function returns a list of all the interpolation keys (patterns in the
  form `%{interpolation}`) contained in its argument.

  If the argument is a segment list, that is, a list of strings and atoms where
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
  @spec keys(String.t() | interpolatable) :: [atom]
  def keys(string_or_interpolatable)

  def keys(string) when is_binary(string), do: string |> to_interpolatable() |> keys()

  def keys(interpolatable) when is_list(interpolatable) do
    interpolatable
    |> Enum.reduce([], fn
      el, acc when is_atom(el) -> [el | acc]
      {el, _inner}, acc when is_atom(el) -> [el | acc]
      _, acc -> acc
    end)
    |> Enum.reverse()
    |> Enum.uniq()
  end
end
