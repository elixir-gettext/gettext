defmodule Gettext.Backend do
  @moduledoc """
  Behaviour that defines the macros that a Gettext backend has to implement.

  These macros are documented in great detail in the documentation for the
  `Gettext` module.
  """

  @doc """
  Translates the given `msgid` in the given `domain`.

  `bindings` is a map of bindings to support interpolation.

  See also `Gettext.dgettext/4`.
  """
  @macrocallback dgettext(domain :: Macro.t, msgid :: String.t, bindings :: Macro.t) ::
    Macro.t

  @doc """
  Same as `dgettext(domain, msgid, %{})`.

  See also `Gettext.dgettext/4`.
  """
  @macrocallback dgettext(domain :: Macro.t, msgid :: String.t) :: Macro.t

  @doc """
  Same as `dgettext("default", msgid, %{})`.

  See also `Gettext.gettext/3`.
  """
  @macrocallback gettext(msgid :: String.t, bindings :: Macro.t) :: Macro.t

  @doc """
  Same as `gettext(msgid, %{})`.

  See also `Gettext.gettext/3`.
  """
  @macrocallback gettext(msgid :: String.t) :: Macro.t

  @doc """
  Translates the given plural translation (`msgid` + `msgid_plural`) in the
  given `domain`.

  `n` is an integer used to determine how to pluralize the
  translation. `bindings` is a map of bindings to support interpolation.

  See also `Gettext.dngettext/6`.
  """
  @macrocallback dngettext(domain :: Macro.t,
                           msgid :: String.t,
                           msgid_plural :: String.t,
                           n :: Macro.t,
                           bindings :: Macro.t) :: Macro.t

  @doc """
  Same as `dngettext(domain, msgid, msgid_plural, n, %{})`.

  See also `Gettext.dngettext/6`.
  """
  @macrocallback dngettext(domain :: Macro.t,
                           msgid :: String.t,
                           msgid_plural :: String.t,
                           n :: Macro.t) :: Macro.t

  @doc """
  Same as `dngettext("default", msgid, msgid_plural, n, bindings)`.

  See also `Gettext.ngettext/5`.
  """
  @macrocallback ngettext(msgid :: String.t,
                          msgid_plural :: String.t,
                          n :: Macro.t,
                          bindings :: Macro.t) :: Macro.t

  @doc """
  Same as `ngettext(msgid, msgid_plural, n, %{})`.

  See also `Gettext.ngettext/5`.
  """
  @macrocallback ngettext(msgid :: String.t,
                          msgid_plural :: String.t,
                          n :: Macro.t) :: Macro.t
end
