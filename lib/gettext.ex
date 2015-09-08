defmodule Gettext do
  @moduledoc ~S"""
  Main Gettext module.

  The `Gettext` module provides a
  [gettext](https://www.gnu.org/software/gettext/)-based API for working with
  localized and internationalized applications.

  For more information on the original GNU gettext remember to refer to the
  official [GNU gettext manual](https://www.gnu.org/software/gettext/manual/gettext.html).

  ## Using Gettext

  To use `Gettext`:

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app
      end

  This will automatically define some macros in the `MyApp.Gettext` module.
  Here are some examples:

      import MyApp.Gettext

      # Simple translation
      gettext "Here is the string to translate"

      # Plural translation
      ngettext "Here is the string to translate",
               "Here are the strings to translate",
               3

      # Domain-based translation
      dgettext "errors", "Here is the string to translate"

  The translation will then be looked up from `.po` files. In the following
  sections we will explore exactly what are those files before we explore
  the "Gettext API" in detail.

  ## Translations

  Translations are stored inside PO (Portable Object) files (with a `.po`
  extension). For example, this is a snippet from a PO file:

      # This is a comment
      msgid "Hello world!"
      msgstr "Ciao mondo!"

  Gettext for Elixir automatically reads and parses PO files in order to make
  translations available.

  Translations for an application must be stored in a directory (usually
  "priv/gettext") with the following structure:

      └─ locale
         └─ LC_MESSAGES
            ├─ domain_1.po
            ├─ domain_2.po
            └─ domain_3.po

  where "locale" is the locale of the translations (for example, "en_US"),
  "LC_MESSAGES" is a fixed directory and `domain_i.po` are PO files containing
  domain-scoped translations. For more information on domains, check out the
  "Domains" section below.

  A concrete example of such a directory structure could look like this:

      └─ en_US
      |  └─ LC_MESSAGES
      |     ├─ default.po
      |     └─ errors.po
      └─ it
         └─ LC_MESSAGES
            ├─ default.po
            └─ errors.po

  By default, Gettext expects translations to be stored under the `priv/gettext`
  directory of an application. For the `:my_app` application, that would be
  `my_app/priv/gettext`. This behaviour can be changed by specifying a `:priv`
  option when using `Gettext`:

      # Look for translations in my_app/translations
      use Gettext, otp_app: :my_app, priv: "translations"

  ### Template files (pot)

  TODO: Describe the process with mix tasks.

  ## Locale

  `Gettext.locale/1` can be used to set the locale, while `Gettext.locale/0` can
  be used to read it. Locales are expressed as strings like `"en"` or `"fr"`;
  they can be arbitrary strings as long as they match a directory name.

  All Gettext-related functions and macros that do not explicitely take a
  locale as an argument read the locale from `Gettext.locale/0`.

  Gettext stores the locale **per-process** (in the process dictionary to be
  precise). This means that `Gettext.locale/1` must be called in every new
  process in order to have the right locale available in that process. Pay
  attention to this behaviour, since not setting the locale with
  `Gettext.locale/1` *will not* result in any errors when `Gettext.locale/0` is
  called; the default locale will be returned instead.

  ### Default locale

  The default Gettext locale is `"en"`. The value of the default locale can be
  modified in the configuration for the `:gettext` application. For example, in
  the `config/config.exs` file of the `my_app` application:

      config :gettext, default_locale: "fr"

  ## Gettext API

  There are two ways to use Gettext:

    * using macros from your own Gettext module, like `MyApp.Gettext`
    * using functions from the `Gettext` module

  These two approaches are different and each one has its own use case.

  ### Using macros

  When a module calls `use Gettext`, the following macros are automatically
  defined inside it:

    * `gettext/2`
    * `dgettext/3`
    * `ngettext/4`
    * `dngettext/5`

  Supposing the caller module is `MyApp.Gettext`, the macros mentioned above
  behave as follows:

    * `gettext(msgid, bindings \\ %{})` -
      like `Gettext.gettext(MyApp.Gettext, msgid, bindings)`
    * `dgettext(domain, msgid, bindings \\ %{})` -
      like `Gettext.dgettext(MyApp.Gettext, domain, msgid, bindings)`
    * `ngettext(msgid, msgid_plural, n, bindings \\ %{})` -
      like `Gettext.ngettext(MyApp.Gettext, msgid, msgid_plural, n, bindings)`
    * `dngettext(domain, msgid, msgid_plural, n, bindings \\ %{})` -
      like `Gettext.dngettext(MyApp.Gettext, domain, msgid, msgid_plural, n, bindings)`

  Using macros are preferred as gettext is able to automatically sync the
  translations in your code with PO files. This, however, imposes a constraint
  that strings passed to any of these macros have to be strings **at compile time**;
  that is, they have to be string literals or something that expands to a string
  literal at compile time. A common example of such a thing is module
  attributes. These are valid calls to Gettext macros:

      Gettext.locale "it"

      MyApp.Gettext.gettext "Hello world"
      #=> "Ciao mondo"

      @msgid "Hello world"
      MyApp.Gettext.gettext @msgid
      #=> "Ciao mondo"

  The `gettext`/`dgettext`/`ngettext`/`dngettext` macros raise an
  `ArgumentError` exception if they receive a `msgid` or a `msgid_plural` that
  doesn't expand to a string at compile time:

      msgid = "Hello world"
      MyApp.Gettext.gettext msgid
      #=> ** (ArgumentError) msgid must be a string literal

  Using compile-time strings isn't always possible. For this reason,
  the `Gettext` module provides a set of functions as well.

  ### Using functions

  If compile-time strings cannot be used, the solution is to use the functions
  in the `Gettext` module instead of the macros described above. These functions
  perfectly mirror the macro API, but they all expect a module name as the first
  argument: this module has to be a module which uses `Gettext`. For example:

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app
      end

      Gettext.locale "pt_BR"

      msgid = "Hello world"
      Gettext.gettext(MyApp.Gettext, msgid)
      #=> "Olá mundo"

  Note however that while using functions from the `Gettext` module yields the
  same results as using macros (with the added benefit of dynamic arguments),
  all the compile-time features mentioned in the previous section are lost.

  ## Domains

  The `dgettext` and `dngettext` functions/macros also accept a *domain* as one
  of the arguments. The domain of a translation is determined by the PO file the
  translation is in. For example, the domain of translations in the file
  `it/LC_MESSAGES/errors.po` is `"errors"`, so those translations would need to
  be retrieved with `dgettext` or `dngettext`:

      MyApp.Gettext.dgettext "errors", "Error!"
      #=> "Errore!"

  When `gettext` or `ngettext` are used, the `"default"` domain is used.

  ## Interpolation

  All `*gettext` functions and macros provided by Gettext support interpolation.
  Interpolation keys can be placed in `msgid`s or `msgid_plural`s with the
  following syntax:

      "This is an %{interpolated} string"

  Interpolation bindings can be passed as an argument to all of the `*gettext`
  functions/macros. For example, given the following PO file for the `"it"`
  locale:

      msgid "Hello, %{name}!"
      msgstr "Ciao, %{name}!"

  interpolation can be done like follows:

      Gettext.locale "it"
      MyApp.Gettext.gettext "Hello, %{name}!", name: "Meg"
      #=> "Ciao, Meg!"

  Interpolation keys that are in a string but not in the provided bindings
  result in a `Gettext.Error` exception:

      MyApp.Gettext.gettext "Hello, %{name}!"
      #=> ** (Gettext.Error) missing interpolation keys: name

  Keys that are in the interpolation bindings but that don't occur in the string
  are ignored. Interpolations in gettext are often expanded at compile time,
  ensuring a low performance cost when running them at runtime.

  ## Pluralization

  Pluralization in Gettext works very similar to how pluralization works in GNU
  gettext. The `*ngettext` functions/macros accept a `msgid`, a `msgid_plural`
  and a count of elements; the right translation is chosen based on the
  **pluralization rule** for the given locale.

  For example, given the following snippet of PO file for the `"it"` locale:

      msgid "One error"
      msgid_plural "%{count} errors"
      msgstr[0] "Un errore"
      msgstr[1] "%{count} errori"

  the `ngettext` macro can be used like this:

      Gettext.locale "it"
      MyApp.Gettext.ngettext "One error", "%{count} errors", 3
      #=> "3 errori"

  While `dngettext` is used as:

      Gettext.locale "it"
      MyApp.Gettext.dngettext "errors", "One error", "%{count} errors", 3
      #=> "3 errori"

  The `%{count}` interpolation key is a special one since it gets replaced by
  the number of elements argument passed to `*ngettext`, like if the `count: 3`
  key-value pair were in the interpolation bindings. Hence, never pass the
  `count` key in the bindings:

      MyApp.Gettext.ngettext "One error", "%{count} errors", 3, count: 4
      #=> "3 errori"

  You can specify a "pluralizer" module via the `:plural_forms` option in the
  configuration for the `:gettext` application.

      # config/config.exs
      config :gettext, plural_forms: MyApp.Plural

  To learn more about pluralization rules, plural forms and what they mean to
  Gettext check the documentation for `Gettext.Plural`.

  ## Missing translations

  When a translation is missing in the specified locale (both with functions as
  well as with macros), the argument is returned:

    * in case of calls to `gettext`/`dgettext`, the `msgid` argument is returned
      as is;
    * in case of calls to `ngettext`/`dngettext`, the `msgid` argument is
      returned in case of a singular value and the `msgid_plural` is returned in
      case of a plural value (following the English pluralization rule).

  For example:

      Gettext.locale "foo"
      MyApp.Gettext.gettext "Hey there"
      #=> "Hey there"
      MyApp.Gettext.ngettext "One error", "%{count} errors", 3
      #=> "3 errors"

  ## Options

  The following a comprehensive list of options that can be passed to `use
  Gettext`.

      defmodule MyApp.Gettext do
        use Gettext, # options
      end

    * `:otp_app` (required) - an atom representing an OTP applications.
      Translations will be searched in directories inside this application's
      diretory (`priv/gettext` by default, see the `:priv` option).
    * `:priv` - a string representing a directory where translations will be
      searched. The directory is relative to the directory of the application
      specified by the `:otp_app` option.

  ## Configuration

  The following is a list of the options with which the `:gettext` application
  can be configured:

      # config/config.exs
      config :gettext, # config options

    * `:plural_forms` - a module which will act as a "pluralizer" module. For
      more information, look at the documentation for `Gettext.Plural`.
    * `:default_locale` - the default locale that will be returned by
      `Gettext.locale/0`. If this config option is not set, `"en"` is used as a
      "default default locale".

  """

  defmodule Error do
    @moduledoc """
    A generic error raised for a variety of possible Gettext-related reasons
    (e.g., missing interpolation keys).
    """
    defexception [:message]

    def exception(message) do
      %__MODULE__{message: message}
    end
  end

  @type locale :: binary
  @type bindings :: %{} | Keyword.t

  @doc false
  defmacro __using__(opts) do
    quote do
      @gettext_opts unquote(opts)
      @before_compile Gettext.Compiler
      unquote(Gettext.Compiler.signatures)
    end
  end

  @doc """
  Gets the locale for the current process.

  This function returns the value of the locale for the current process. If
  there is no locale for the current process, the default locale is set as the
  locale for the current process and then returned. For more information on the
  default locale and how it can be set, refer to the documentation of the
  `Gettext` module.

  ## Examples

      Gettext.locale()
      #=> "en"

  """
  @spec locale() :: locale
  def locale do
    if locale = Process.get(__MODULE__) do
      locale
    else
      default_locale = Application.get_env(:gettext, :default_locale)
      Process.put(__MODULE__, default_locale)
      default_locale
    end
  end

  @doc """
  Sets the locale for the current process.

  The locale is stored in the process dictionary. `locale` must be a string; if
  it's not, an `ArgumentError` exception is raised.

  ## Examples

      Gettext.locale("pt_BR")
      #=> nil
      Gettext.locale()
      #=> "pt_BR"

  """
  @spec locale(locale) :: nil
  def locale(locale) when is_binary(locale),
    do: Process.put(__MODULE__, locale)
  def locale(_),
    do: raise(ArgumentError, "locale/1 only accepts binary locales")

  @doc """
  Returns the translation of the given string in the given domain.

  The string is translated by the `backend` module.

  The translated string is interpolated based on the `bindings` argument. For
  more information on how interpolation works, refer to the documentation of the
  `Gettext` module.

  If the translation for the given `msgid` is not found, the `msgid`
  (interpolated if necessary) is returned.

  ## Examples

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app
      end

      Gettext.locale("it")

      Gettext.dgettext(MyApp.Gettext, "errors", "Invalid")
      #=> "Non valido"

      Gettext.dgettext(MyApp.Gettext, "errors", "%{name} is not a valid name", name: "Meg")
      #=> "Meg non è un nome valido"

      Gettext.dgettext(MyApp.Gettext, "alerts", "nonexisting")
      #=> "nonexisting"

  """
  @spec dgettext(module, binary, binary, bindings) :: binary
  def dgettext(backend, domain, msgid, bindings \\ %{})

  def dgettext(backend, domain, msgid, bindings) when is_list(bindings) do
    dgettext(backend, domain, msgid, Enum.into(bindings, %{}))
  end

  def dgettext(backend, domain, msgid, bindings) do
    backend.lgettext(locale(), domain, msgid, bindings)
    |> handle_backend_result
  end

  @doc """
  Returns the translation of the given string in the `"default"` domain.

  Works exactly like:

      Gettext.dgettext(backend, "default", msgid, bindings)

  """
  @spec gettext(module, binary, bindings) :: binary
  def gettext(backend, msgid, bindings \\ %{}) do
    dgettext(backend, "default", msgid, bindings)
  end

  @doc """
  Returns the pluralized translation of the given string in the given domain.

  The string is translated and pluralized by the `backend` module.

  The translated string is interpolated based on the `bindings` argument. For
  more information on how interpolation works, refer to the documentation of the
  `Gettext` module.

  If the translation for the given `msgid` and `msgid_plural` is not found, the
  `msgid` or `msgid_plural` (based on `n` being singular or plural) is returned
  (interpolated if necessary).

  ## Examples

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app
      end

      Gettext.dngettext(MyApp.Gettext, "errors", "Error", "%{count} errors", 3)
      #=> "3 errori"
      Gettext.dngettext(MyApp.Gettext, "errors", "Error", "%{count} errors", 1)
      #=> "Errore"

  """
  @spec dngettext(module, binary, binary, binary, non_neg_integer, bindings) :: binary
  def dngettext(backend, domain, msgid, msgid_plural, n, bindings \\ %{})

  def dngettext(backend, domain, msgid, msgid_plural, n, bindings) when is_list(bindings) do
    dngettext(backend, domain, msgid, msgid_plural, n, Enum.into(bindings, %{}))
  end

  def dngettext(backend, domain, msgid, msgid_plural, n, bindings) do
    backend.lngettext(locale(), domain, msgid, msgid_plural, n, bindings)
    |> handle_backend_result
  end

  @doc """
  Returns the pluralized translation of the given string in the `"default"`
  domain.

  Works exactly like:

      Gettext.dngettext(backend, "default", msgid, msgid_plural, n, bindings)

  """
  @spec ngettext(module, binary, binary, non_neg_integer, bindings) :: binary
  def ngettext(backend, msgid, msgid_plural, n, bindings \\ %{}) do
    dngettext(backend, "default", msgid, msgid_plural, n, bindings)
  end

  defp handle_backend_result({atom, string}) when atom in [:ok, :default],
    do: string
  defp handle_backend_result({:error, error}),
    do: raise(Error, error)
end
