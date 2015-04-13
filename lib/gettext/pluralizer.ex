defmodule Gettext.Pluralizer do
  @moduledoc """
  Behaviour to find the plural form to which a number of elements belongs to in
  a given locale.

  ## Examples

      defmodule ElvishPluralizer do
        use Gettext.Pluralizer

        def nplurals("elv") do
          2
        end

        def plural("elv", 1) do
          0
        end

        def plural("elv", _) do
          1
        end
      end

  """

  use Behaviour

  @doc """
  Returns the number of possible plural forms in the given `locale`.
  """
  defcallback nplurals(locale :: String.t)
    :: non_neg_integer

  @doc """
  Returns the plural form in the given `locale` for the given `count` of
  elements.
  """
  defcallback plural(locale :: String.t, count :: non_neg_integer)
    :: (plural_form :: non_neg_integer)
end
