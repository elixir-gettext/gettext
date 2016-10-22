defmodule Gettext.Backend do
  @moduledoc """
  Behaviour that defines the macros that a Gettext backend has to implement.

  These macros are documented in great detail in the documentation for the
  `Gettext` module.
  """


  @doc """
  Default handling for missing bindings.

  This function is called when there are missing bindings in a translation.
  It takes the `Gettext.MissingBindingsError` struct and the incomplete translation.
  The current backend, locale, domain and msgid can be found in the error struct.
  For example, if something like this is called:

      MyApp.Gettext.gettext("Hello %{name}, welcome to %{country}", name: "Jane", country: "Italy")

  and our `it/LC_MESSAGES/default.po` looks like this:

      msgid "Hello %{name}, welcome to %{country}"
      msgstr "Ciao %{name}, benvenuto in %{cowntry}" # (typo)

  then Gettext will call:

      MyApp.Gettext.handle_missing_bindings(%Gettext.MissingBindingsError{...},
                                            "Ciao Jane, benvenuto in %{cowntry}")

  The default implementation for this function uses `Logger.error/1` to warn
  about the missing binding and returns the incomplete message.

  This function can be overridden to raise, for example:

      def handle_missing_bindings(exception, _incomplete) do
        raise exception
      end
  """
  @callback handle_missing_bindings(Gettext.MissingBindingsError.t, binary) ::
    binary | no_return

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
