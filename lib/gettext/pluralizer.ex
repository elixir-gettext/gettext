defmodule Gettext.Pluralizer do
  use Behaviour

  defcallback nplurals(locale :: String.t)
    :: non_neg_integer
  defcallback plural(locale :: String.t, quantity :: non_neg_integer)
    :: (plural_form :: non_neg_integer)
end
