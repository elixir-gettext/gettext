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
  def to_interpolatable(string, opts \\ [mode: :atom])

  @spec to_interpolatable(String.t()) :: interpolatable
  def to_interpolatable(string, opts) do
    start_pattern = :binary.compile_pattern("%{")
    end_pattern = :binary.compile_pattern("}")

    string
    |> to_interpolatable(_current = "", _acc = [], start_pattern, end_pattern, opts)
    |> Enum.reverse()
  end

  defp to_interpolatable(string, current, acc, start_pattern, end_pattern, opts) do
    case :binary.split(string, start_pattern) do
      # If we have one element, no %{ was found so this is the final part of the
      # string.
      [rest] ->
        prepend_if_not_empty(current <> rest, acc)

      # If we found a %{ but it's followed by an immediate }, then we just
      # append %{} to the current string and keep going.
      [before, "}" <> rest] ->
        new_current = current <> before <> "%{}"
        to_interpolatable(rest, new_current, acc, start_pattern, end_pattern, opts)

      # Otherwise, we found the start of a binding.
      [before, binding_and_rest] ->
        case :binary.split(binding_and_rest, end_pattern) do
          # If we don't find the end of this binding, it means we're at a string
          # like "foo %{ no end". In this case we consider no bindings to be
          # there.
          [_] ->
            [current <> string | acc]

          # This is the case where we found a binding, so we put it in the acc
          # and keep going.
          [binding, rest] ->
            mode = Keyword.get(opts, :mode)

            binding =
              if mode == :atom do
                String.to_atom(binding)
              else
                "%{#{binding}}"
              end

            new_acc = [binding | prepend_if_not_empty(before, acc)]

            to_interpolatable(rest, "", new_acc, start_pattern, end_pattern, opts)
        end
    end
  end

  defp prepend_if_not_empty("", list), do: list
  defp prepend_if_not_empty(string, list), do: [string | list]

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
  def interpolate(interpolatable, bindings, opts \\ [mode: :atom])

  def interpolate(interpolatable, bindings, opts)
      when is_list(interpolatable) and is_map(bindings) do
    interpolate(interpolatable, bindings, [], [], opts)
  end

  defp interpolate([string | segments], bindings, strings, missing, opts)
       when is_binary(string) do
    if Keyword.get(opts, :mode) == :atom do
      interpolate(segments, bindings, [string | strings], missing, opts)
    else
      clean_string =
        if String.starts_with?(string, "%{") do
          "%{" <> dirty_string = string
          String.trim_trailing(dirty_string, "}")
        end

      case bindings do
        %{^clean_string => value} ->
          interpolate(segments, bindings, [to_string(value) | strings], missing, opts)

        %{} ->
          if is_nil(clean_string) do
            strings = ["#{string}" | strings]

            interpolate(segments, bindings, strings, missing, opts)
          else
            strings = [string | strings]
            interpolate(segments, bindings, strings, [clean_string | missing], opts)
          end
      end
    end
  end

  defp interpolate([atom | segments], bindings, strings, missing, opts) when is_atom(atom) do
    case bindings do
      %{^atom => value} ->
        interpolate(segments, bindings, [to_string(value) | strings], missing, opts)

      %{} ->
        strings = ["%{" <> Atom.to_string(atom) <> "}" | strings]
        interpolate(segments, bindings, strings, [atom | missing], opts)
    end
  end

  defp interpolate([], _bindings, strings, [], _opts) do
    {:ok, IO.iodata_to_binary(Enum.reverse(strings))}
  end

  defp interpolate([], _bindings, strings, missing, _opts) do
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

  def keys(interpolatable) when is_list(interpolatable),
    do: interpolatable |> Enum.filter(&is_atom/1) |> Enum.uniq()
end
