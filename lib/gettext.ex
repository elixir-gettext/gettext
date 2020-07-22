defmodule Gettext do
  @moduledoc ~S"""
  The `Gettext` module provides a
  [gettext](https://www.gnu.org/software/gettext/)-based API for working with
  internationalized applications.

  ## Using Gettext

  To use `Gettext`, a module that calls `use Gettext` has to be defined:

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app
      end

  This automatically defines some macros in the `MyApp.Gettext` module.
  Here are some examples:

      import MyApp.Gettext

      # Simple translation
      gettext("Here is the string to translate")

      # Plural translation
      ngettext(
        "Here is the string to translate",
        "Here are the strings to translate",
        3
      )

      # Domain-based translation
      dgettext("errors", "Here is the error message to translate")

      # Context-based translation
      pgettext("email", "Email text to translate")

      # All of the above
      dpngettext(
        "errors",
        "context",
        "Here is the string to translate",
        "Here are the strings to translate",
        3
      )

  The arguments for the Gettext macros and their order can be derived froe
  their names. For `dpgettext/4` the arguments are: `domain`, `context`,
  `msgid`, `bindings` (default to `%{}`).

  Translations are looked up from `.po` files. In the following sections we will
  explore exactly what are those files before we explore the "Gettext API" in
  detail.

  ## Translations

  Translations are stored inside PO (Portable Object) files, with a `.po`
  extension. For example, this is a snippet from a PO file:

      # This is a comment
      msgid "Hello world!"
      msgstr "Ciao mondo!"

  PO files containing translations for an application must be stored in a
  directory (by default it's `priv/gettext`) that has the following structure:

      gettext directory
      └─ locale
         └─ LC_MESSAGES
            ├─ domain_1.po
            ├─ domain_2.po
            └─ domain_3.po

  Here, `locale` is the locale of the translations (for example, `en_US`),
  `LC_MESSAGES` is a fixed directory, and `domain_i.po` are PO files containing
  domain-scoped translations. For more information on domains, check out the
  "Domains" section below.

  A concrete example of such a directory structure could look like this:

      priv/gettext
      └─ en_US
      |  └─ LC_MESSAGES
      |     ├─ default.po
      |     └─ errors.po
      └─ it
         └─ LC_MESSAGES
            ├─ default.po
            └─ errors.po

  By default, Gettext expects translations to be stored under the `priv/gettext`
  directory of an application. This behaviour can be changed by specifying a
  `:priv` option when using `Gettext`:

      # Look for translations in my_app/priv/translations instead of
      # my_app/priv/gettext
      use Gettext, otp_app: :my_app, priv: "priv/translations"

  The translations directory specified by the `:priv` option should be a directory
  inside `priv/`, otherwise some things (like `mix compile.gettext`) won't work
  as expected.

  ## Locale

  At runtime, all gettext-related functions and macros that do not explicitly
  take a locale as an argument read the locale from the backend locale and
  fallbacks to Gettext's locale.

  `Gettext.put_locale/1` can be used to change the locale of all backends for
  the current Elixir process. That's the preferred mechanism for setting the
  locale at runtime. `Gettext.put_locale/2` can be used when you want to set the
  locale of one specific Gettext backend without affecting other Gettext
  backends.

  Similarly, `Gettext.get_locale/0` gets the locale for all backends in the
  current process. `Gettext.get_locale/1` gets the locale of a specific backend
  for the current process. Check their documentation for more information.

  Locales are expressed as strings (like `"en"` or `"fr"`); they can be
  arbitrary strings as long as they match a directory name. As mentioned above,
  the locale is stored **per-process** (in the process dictionary): this means
  that the locale must be set in every new process in order to have the right
  locale available for that process. Pay attention to this behaviour, since not
  setting the locale *will not* result in any errors when `Gettext.get_locale/0`
  or `Gettext.get_locale/1` are called; the default locale will be
  returned instead.

  To decide which locale to use, each gettext-related function in a given
  backend follows these steps:

    * if there is a backend-specific locale for the given backend for this
      process (see `put_locale/2`), use that, otherwise
    * if there is a global locale for this process (see `put_locale/1`), use
      that, otherwise
    * if there is a backend-specific default locale in the configuration for
      that backend's `:otp_app` (see the "Default locale" section below), use
      that, otherwise
    * use the default global Gettext locale (see the "Default locale" section
      below)

  ### Default locale

  The global Gettext default locale can be configured through the
  `:default_locale` key of the `:gettext` application:

      config :gettext, :default_locale, "fr"

  By default the global locale is `"en"`. See also `get_locale/0` and
  `put_locale/1`.

  If for some reason a backend requires a different `:default_locale`
  than all other backends, you can set the `:default_locale` inside the
  backend configuration, but this approach is generally discouraged as
  it makes it hard to track which locale each backend is using:

      config :my_app, MyApp.Gettext, default_locale: "fr"

  ### Default Domain

  Each backend can be configured with a specific `:default_domain`
  that replaces `"default"` in `gettext/2`, `pgettext/3`, and `ngettext/4`
  for that backend.

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app, default_domain: "messages"
      end

      config :my_app, MyApp.Gettext, default_domain: "translations"

  ## Gettext API

  There are two ways to use Gettext:

    * using macros from your own Gettext module, like `MyApp.Gettext`
    * using functions from the `Gettext` module

  These two approaches are different and each one has its own use case.

  ### Using macros

  Each module that calls `use Gettext` is usually referred to as a "Gettext
  backend", as it implements the `Gettext.Backend` behaviour. When a module
  calls `use Gettext`, the following macros are automatically
  defined inside it:

    * `gettext/2`
    * `dgettext/3`
    * `pgettext/3`
    * `dpgettext/4`
    * `ngettext/4`
    * `dngettext/5`
    * `pngettext/5`
    * `dpngettext/6`
    * all macros above with a `_noop` suffix (and without accepting bindings), for
      example `pgettext_noop/2`

  Supposing the caller module is `MyApp.Gettext`, the macros mentioned above
  behave as follows:

    * `gettext(msgid, bindings \\ %{})` -
      like `Gettext.gettext(MyApp.Gettext, msgid, bindings)`

    * `dgettext(domain, msgid, bindings \\ %{})` -
      like `Gettext.dgettext(MyApp.Gettext, domain, msgid, bindings)`

    * `pgettext(msgctxt, msgid, bindings \\ %{})` -
      like `Gettext.pgettext(MyApp.Gettext, msgctxt, msgid, bindings)`

    * `dpgettext(domain, msgctxt, msgid, bindings \\ %{})` -
      like `Gettext.dpgettext(MyApp.Gettext, domain, msgctxt, msgid, bindings)`

    * `ngettext(msgid, msgid_plural, n, bindings \\ %{})` -
      like `Gettext.ngettext(MyApp.Gettext, msgid, msgid_plural, n, bindings)`

    * `dngettext(domain, msgid, msgid_plural, n, bindings \\ %{})` -
      like `Gettext.dngettext(MyApp.Gettext, domain, msgid, msgid_plural, n, bindings)`

    * `pngettext(msgctxt, msgid, msgid_plural, n, bindings \\ %{})` -
      like `Gettext.pngettext(MyApp.Gettext, msgctxt, msgid, msgid_plural, n, bindings)`

    * `dpngettext(domain, msgctxt, msgid, msgid_plural, n, bindings \\ %{})` -
      like `Gettext.dpngettext(MyApp.Gettext, domain, msgctxt, msgid, msgid_plural, n, bindings)`

    * `*_noop` family of functions - used to mark translations for extraction
      without translating them. See the documentation for these macros in
      `Gettext.Backend`

  See also the `Gettext.Backend` behaviour for more detailed documentation about
  these macros.

  Using macros is preferred as Gettext is able to automatically sync the
  translations in your code with PO files. This, however, imposes a constraint:
  arguments passed to any of these macros have to be strings **at compile
  time**. This means that they have to be string literals or something that
  expands to a string literal at compile time (for example, a module attribute like
  `@my_string "foo"`).

  These are all valid uses of the Gettext macros:

      Gettext.put_locale(MyApp.Gettext, "it")

      MyApp.Gettext.gettext("Hello world")
      #=> "Ciao mondo"

      @msgid "Hello world"
      MyApp.Gettext.gettext(@msgid)
      #=> "Ciao mondo"

  The `*gettext` macros raise an `ArgumentError` exception if they receive a
  `domain`, `msgctxt`, `msgid`, or `msgid_plural` that doesn't expand to a string
  *at compile time*:

      msgid = "Hello world"
      MyApp.Gettext.gettext(msgid)
      #=> ** (ArgumentError) msgid must be a string literal

  Using compile-time strings isn't always possible. For this reason,
  the `Gettext` module provides a set of functions as well.

  ### Using functions

  If compile-time strings cannot be used, the solution is to use the functions
  in the `Gettext` module instead of the macros described above. These functions
  perfectly mirror the macro API, but they all expect a module name as the first
  argument. This module has to be a module which calls `use Gettext`. For example:

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app
      end

      Gettext.put_locale(MyApp.Gettext, "pt_BR")

      msgid = "Hello world"
      Gettext.gettext(MyApp.Gettext, msgid)
      #=> "Olá mundo"

  While using functions from the `Gettext` module yields the same results as
  using macros (with the added benefit of dynamic arguments), all the
  compile-time features mentioned in the previous section are lost.

  ## Domains

  The `dgettext` and `dngettext` functions/macros also accept a *domain* as one
  of the arguments. The domain of a translation is determined by the name of the
  PO file that contains that translation. For example, the domain of
  translations in the `it/LC_MESSAGES/errors.po` file is `"errors"`, so those
  translations would need to be retrieved with `dgettext` or `dngettext`:

      MyApp.Gettext.dgettext("errors", "Error!")
      #=> "Errore!"

  When backend `gettext`, `ngettext`, or `pgettext` are used, the backend's
  default domain is used (which defaults to "default"). The `Gettext`
  functions accepting a backend (`gettext/3`, `ngettext/5`, and `pgettext/4`)
  _always_ use a domain of "default".

  ## Contexts

  The GNU Gettext implementation supports
  [*contexts*](https://www.gnu.org/software/gettext/manual/html_node/Contexts.html),
  which are a way to contextualize translations. For example, in English, the
  word "file" could be used both as a noun as well as a verb. Contexts can be used to
  solve similar problems: you could have a `imperative_verbs` context and a
  `nouns` context as to avoid ambiguity. The functions that handle contexts
  have a `p` in their name (to match the GNU Gettext API), and are `pgettext`,
  `dpgettext`, `pngettext`, and `dpngettext`. The "p" stands for "particular".

  ## Interpolation

  All `*gettext` functions and macros provided by Gettext support interpolation.
  Interpolation keys can be placed in `msgid`s or `msgid_plural`s with by
  enclosing them in `%{` and `}`, like this:

      "This is an %{interpolated} string"

  Interpolation bindings can be passed as an argument to all of the `*gettext`
  functions/macros. For example, given the following PO file for the `"it"`
  locale:

      msgid "Hello, %{name}!"
      msgstr "Ciao, %{name}!"

  interpolation can be done like follows:

      Gettext.put_locale(MyApp.Gettext, "it")
      MyApp.Gettext.gettext("Hello, %{name}!", name: "Meg")
      #=> "Ciao, Meg!"

  Interpolation keys that are in a string but not in the provided bindings
  result in a `Gettext.Error` exception:

      MyApp.Gettext.gettext("Hello, %{name}!")
      #=> ** (Gettext.Error) missing interpolation keys: name

  Keys that are in the interpolation bindings but that don't occur in the string
  are ignored. Interpolations in Gettext are often expanded at compile time,
  ensuring a low performance cost when running them at runtime.

  ## Pluralization

  Pluralization in Gettext for Elixir works very similar to how pluralization
  works in GNU Gettext. The `*ngettext` functions/macros accept a `msgid`, a
  `msgid_plural` and a count of elements; the right translation is chosen based
  on the **pluralization rule** for the given locale.

  For example, given the following snippet of PO file for the `"it"` locale:

      msgid "One error"
      msgid_plural "%{count} errors"
      msgstr[0] "Un errore"
      msgstr[1] "%{count} errori"

  the `ngettext` macro can be used like this:

      Gettext.put_locale(MyApp.Gettext, "it")
      MyApp.Gettext.ngettext("One error", "%{count} errors", 3)
      #=> "3 errori"

  The `%{count}` interpolation key is a special key since it gets replaced by
  the number of elements argument passed to `*ngettext`, like if the `count: 3`
  key-value pair were in the interpolation bindings. Hence, never pass the
  `count` key in the bindings:

      # `count: 4` is ignored here
      MyApp.Gettext.ngettext("One error", "%{count} errors", 3, count: 4)
      #=> "3 errori"

  You can specify a "pluralizer" module via the `:plural_forms` option in the
  configuration for each Gettext backend.

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app, plural_forms: MyApp.PluralForms
      end

  To learn more about pluralization rules, plural forms and what they mean to
  Gettext check the documentation for `Gettext.Plural`.

  ## Missing translations

  When a translation is missing in the specified locale (both with functions as
  well as with macros), the argument is returned:

    * in case of calls to `gettext`/`dgettext`/`pgettext`/`dpgettext`, the `msgid` argument is returned
      as is;
    * in case of calls to `ngettext`/`dngettext`/`pngettext`/`dpngettext`, the `msgid` argument is
      returned in case of a singular value and the `msgid_plural` is returned in
      case of a plural value (following the English pluralization rule).

  For example:

      Gettext.put_locale(MyApp.Gettext, "foo")
      MyApp.Gettext.gettext("Hey there")
      #=> "Hey there"
      MyApp.Gettext.ngettext("One error", "%{count} errors", 3)
      #=> "3 errors"

  ### Empty translations

  When a `msgstr` is empty (`""`), the translation is considered missing and the
  behaviour described above for missing translation is applied. A plural
  translation is considered to have an empty `msgstr` if at least one
  translation in the `msgstr` is empty.

  ## Compile-time features

  As mentioned above, using the Gettext macros (as opposed to functions) allows
  Gettext to operate on those translations *at compile-time*. This can be used
  to extract translations from the source code into POT files automatically
  (instead of having to manually add translations to POT files when they're added
  to the source code). The `gettext.extract` does exactly this: whenever there
  are new translations in the source code, running `gettext.extract` syncs the
  existing POT files with the changed code base. Read the documentation for
  `Mix.Tasks.Gettext.Extract` for more information on the extraction process.

  POT files are just *template* files and the translations in them do not
  actually contain translated strings. A POT file looks like this:

      # The msgstr is empty
      msgid "hello, world"
      msgstr ""

  Whenever a POT file changes, it's likely that developers (or translators) will
  want to update the corresponding PO files for each locale. To do that, gettext
  provides the `gettext.merge` Mix task. For example, running:

      mix gettext.merge priv/gettext --locale pt_BR

  will update all the PO files in `priv/gettext/pt_BR/LC_MESSAGES` with the new
  version of the POT files in `priv/gettext`. Read more about the merging
  process in the documentation for `Mix.Tasks.Gettext.Merge`.

  Finally, Gettext is able to recompile modules that call `use Gettext` whenever
  PO files change. To enable this feature, the `:gettext` compiler needs to be
  added to the list of Mix compilers. In `mix.exs`:

      def project do
        [compilers: [:gettext] ++ Mix.compilers]
      end

  ## Configuration

  ### `:gettext` configuration

  The `:gettext` application supports the following configuration options:

    * `:default_locale` - a string which specifies the default global Gettext
      locale to use for all backends. See the "Locale" section for more
      information on backend-specific, global, and default locales.

  ### Backend configuration

  A **Gettext backend** supports some options to be configured. These options
  can be configured in two ways: either by passing them to `use Gettext` (hence
  at compile time):

      defmodule MyApp.Gettext do
        use Gettext, options
      end

  or by using Mix configuration, configuring the key corresponding to the
  backend in the configuration for your application:

      # For example, in config/config.exs
      config :my_app, MyApp.Gettext, options

  Note that the `:otp_app` option (an atom representing an OTP application) has
  to always be present and has to be passed to `use Gettext` because it's used
  to determine the application to read the configuration of (`:my_app` in the
  example above); for this reason, `:otp_app` can't be configured via the Mix
  configuration. This option is also used to determine the application's
  directory where to search translations in.

  The following is a comprehensive list of supported options:

    * `:priv` - a string representing a directory where translations will be
      searched. The directory is relative to the directory of the application
      specified by the `:otp_app` option. It is recommended to always have
      this directory inside `"priv"`, otherwise some features like the
      "mix compile.gettext" won't work as expected. By default it's
      `"priv/gettext"`.

    * `:plural_forms` - a module which will act as a "pluralizer". For more
      information, look at the documentation for `Gettext.Plural`.

    * `:default_locale` - a string which specifies the default locale to use for
      the given backend.

    * `:one_module_per_locale` - instead of bundling all locales into a single
      module, this option makes Gettext build one internal module per locale.
      This reduces compilation times and beam file sizes for large projects.
      This option requires Elixir v1.6.

    * `:allowed_locales` - a list of locales to bundle in the backend.
      Defaults to all the locales discovered in the `:priv` directory.
      This option can be useful in development to reduce compile-time
      by compiling only a subset of all available locales.

  ### Mix tasks configuration

  You can configure Gettext Mix tasks under the `:gettext` key in the
  configuration returned by `project/0` in `mix.exs`:

      def project() do
        [app: :my_app,
         # ...
         gettext: [...]]
      end

  The following is a list of the supported configuration options:

    * `:fuzzy_threshold` - the default threshold for the Jaro distance measuring
      the similarity of translations. Look at the documentation for the `mix
      gettext.merge` task (`Mix.Tasks.Gettext.Merge`) for more information on
      fuzzy translations.

    * `:excluded_refs_from_purging` - a regex that is matched against translation
      references. Gettext will preserve all translations in all POT files that
      have a matching reference. You can use this pattern to prevent Gettext from
      removing translations that you have extracted using another tool.

    * `:compiler_po_wildcard` - a binary that specifies the wildcard that the
      `:gettext` compiler will use to find changed PO files in order to recompile
      their respective Gettext backends. This wildcard has to be relative to the
      `"priv"` directory of your application. Defaults to
      `"gettext/*/LC_MESSAGES/*.po"`.

    * `:write_reference_comments` - a boolean that specifies whether reference
      comments should be written when outputting PO(T) files. If this is `false`,
      reference comments will not be written when extracting translations or merging
      translations, and the ones already found in files will be discarded.

    * `:sort_by_msgid` - a boolean that modifies the sorting behavior.
      By default, the order of existing translations in a POT file is kept and new
      translations are appended to the file. If `:sort_by_msgid` is set to `true`,
      existing and new translations will be mixed and sorted alphabetically by msgid.

  """

  defmodule Error do
    @moduledoc """
    A generic error raised for a variety of possible Gettext-related reasons
    (for example, missing interpolation keys).
    """
    defexception [:message]
  end

  defmodule PluralFormError do
    @enforce_keys [:form, :locale, :file, :line]
    defexception [:form, :locale, :file, :line]

    @type t() :: %__MODULE__{}

    def message(%{form: form, locale: locale, file: file, line: line}) do
      "plural form #{form} is required for locale #{inspect(locale)} " <>
        "but is missing for translation compiled from #{file}:#{line}"
    end
  end

  defmodule MissingBindingsError do
    @moduledoc """
    An error message raised for missing bindings errors.
    """

    @enforce_keys [:backend, :domain, :msgctxt, :locale, :msgid, :missing]
    defexception [:backend, :domain, :msgctxt, :locale, :msgid, :missing]

    @type t() :: %__MODULE__{}

    def message(%{
          backend: backend,
          domain: domain,
          msgctxt: msgctxt,
          locale: locale,
          msgid: msgid,
          missing: missing
        }) do
      "missing Gettext bindings: #{inspect(missing)} (backend #{inspect(backend)}, " <>
        "locale #{inspect(locale)}, domain #{inspect(domain)}, msgctxt #{inspect(msgctxt)}, " <>
        "msgid #{inspect(msgid)})"
    end
  end

  @type locale :: binary
  @type backend :: module
  @type bindings :: map() | Keyword.t()

  @doc false
  defmacro __using__(opts) do
    quote do
      require Logger

      @gettext_opts unquote(opts)
      @before_compile Gettext.Compiler

      def handle_missing_bindings(exception, incomplete) do
        _ = Logger.error(Exception.message(exception))
        incomplete
      end

      defoverridable handle_missing_bindings: 2

      def handle_missing_translation(_locale, domain, msgid, bindings) do
        import Gettext.Interpolation, only: [to_interpolatable: 1, interpolate: 2]

        Gettext.Compiler.warn_if_domain_contains_slashes(domain)

        with {:ok, interpolated} <- interpolate(to_interpolatable(msgid), bindings),
             do: {:default, interpolated}
      end

      def handle_missing_plural_translation(_locale, domain, msgid, msgid_plural, n, bindings) do
        import Gettext.Interpolation, only: [to_interpolatable: 1, interpolate: 2]

        Gettext.Compiler.warn_if_domain_contains_slashes(domain)
        string = if n == 1, do: msgid, else: msgid_plural
        bindings = Map.put(bindings, :count, n)

        with {:ok, interpolated} <- interpolate(to_interpolatable(string), bindings),
             do: {:default, interpolated}
      end

      defoverridable handle_missing_translation: 4, handle_missing_plural_translation: 6
    end
  end

  @doc """
  Gets the global Gettext locale for the current process.

  This function returns the value of the global Gettext locale for the current
  process. This global locale is shared between all Gettext backends; if you
  want backend-specific locales, see `get_locale/1` and `put_locale/2`. If the
  global Gettext locale is not set, this function returns the default global
  locale (configurable in the configuration for the `:gettext` application, see
  the module documentation for more information).

  ## Examples

      Gettext.get_locale()
      #=> "en"

  """
  @spec get_locale() :: locale
  def get_locale() do
    with nil <- Process.get(Gettext) do
      # If this is not set by the user, it's still set in mix.exs (to "en").
      Application.fetch_env!(:gettext, :default_locale)
    end
  end

  @doc """
  Sets the global Gettext locale for the current process.

  The locale is stored in the process dictionary. `locale` must be a string; if
  it's not, an `ArgumentError` exception is raised.

  ## Examples

      Gettext.put_locale("pt_BR")
      #=> nil
      Gettext.get_locale()
      #=> "pt_BR"

  """
  @spec put_locale(locale) :: nil
  def put_locale(locale) when is_binary(locale), do: Process.put(Gettext, locale)

  def put_locale(locale),
    do: raise(ArgumentError, "put_locale/1 only accepts binary locales, got: #{inspect(locale)}")

  @doc """
  Gets the locale for the current process and the given backend.

  This function returns the value of the locale for the current process and the
  given `backend`. If there is no locale for the current process and the given
  backend, then either the global Gettext locale (if set), or the default locale
  for the given backend, or the global default locale is returned. See the
  "Locale" section in the module documentation for more information.

  ## Examples

      Gettext.get_locale(MyApp.Gettext)
      #=> "en"

  """
  @spec get_locale(backend) :: locale
  def get_locale(backend) do
    with nil <- Process.get(backend),
         nil <- Process.get(Gettext) do
      backend.__gettext__(:default_locale)
    end
  end

  @doc """
  Sets the locale for the current process and the given `backend`.

  The locale is stored in the process dictionary. `locale` must be a string; if
  it's not, an `ArgumentError` exception is raised.

  ## Examples

      Gettext.put_locale(MyApp.Gettext, "pt_BR")
      #=> nil
      Gettext.get_locale(MyApp.Gettext)
      #=> "pt_BR"

  """
  @spec put_locale(backend, locale) :: nil
  def put_locale(backend, locale) when is_binary(locale), do: Process.put(backend, locale)

  def put_locale(_backend, locale),
    do: raise(ArgumentError, "put_locale/2 only accepts binary locales, got: #{inspect(locale)}")

  @doc """
  Returns the translation of the given string with a given context in the given domain.

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

      Gettext.put_locale(MyApp.Gettext, "it")

      Gettext.dpgettext(MyApp.Gettext, "errors", "user error", "Invalid")
      #=> "Non valido"

      Gettext.dgettext(MyApp.Gettext, "errors", "signup form", "%{name} is not a valid name", name: "Meg")
      #=> "Meg non è un nome valido"

  """
  @spec dpgettext(module, binary, binary | nil, binary, bindings) :: binary
  def dpgettext(backend, domain, msgctxt, msgid, bindings \\ %{})

  def dpgettext(backend, domain, msgctxt, msgid, bindings) when is_list(bindings) do
    dpgettext(backend, domain, msgctxt, msgid, Map.new(bindings))
  end

  def dpgettext(backend, domain, msgctxt, msgid, bindings)
      when is_atom(backend) and is_binary(domain) and is_binary(msgid) and is_map(bindings) do
    locale = get_locale(backend)
    result = backend.lgettext(locale, domain, msgctxt, msgid, bindings)
    handle_backend_result(result, backend, locale, domain, msgctxt, msgid)
  end

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

      Gettext.put_locale(MyApp.Gettext, "it")

      Gettext.dgettext(MyApp.Gettext, "errors", "Invalid")
      #=> "Non valido"

      Gettext.dgettext(MyApp.Gettext, "errors", "%{name} is not a valid name", name: "Meg")
      #=> "Meg non è un nome valido"

      Gettext.dgettext(MyApp.Gettext, "alerts", "nonexisting")
      #=> "nonexisting"

  """
  @spec dgettext(module, binary, binary, bindings) :: binary
  def dgettext(backend, domain, msgid, bindings \\ %{}) do
    dpgettext(backend, domain, nil, msgid, bindings)
  end

  @doc """
  Returns the translation of the given string with the given context

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

      Gettext.put_locale(MyApp.Gettext, "it")

      Gettext.pgettext(MyApp.Gettext, "user-interface", "Invalid")
      #=> "Non valido"

      Gettext.pgettext(MyApp.Gettext, "user-interface", "%{name} is not a valid name", name: "Meg")
      #=> "Meg non è un nome valido"

      Gettext.pgettext(MyApp.Gettext, "alerts-users", "nonexisting")
      #=> "nonexisting"
  """
  @spec pgettext(module, binary, binary, bindings) :: binary
  def pgettext(backend, msgctxt, msgid, bindings \\ %{}) do
    dpgettext(backend, "default", msgctxt, msgid, bindings)
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
  Returns the pluralized translation of the given string with a given context in the given domain.

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

      Gettext.dpngettext(MyApp.Gettext, "errors", "user error", "Error", "%{count} errors", 3)
      #=> "3 errori"
      Gettext.dpngettext(MyApp.Gettext, "errors", "user error", "Error", "%{count} errors", 1)
      #=> "Errore"

  """
  @spec dpngettext(module, binary, binary | nil, binary, binary, non_neg_integer, bindings) ::
          binary
  def dpngettext(backend, domain, msgctxt, msgid, msgid_plural, n, bindings \\ %{})

  def dpngettext(backend, domain, msgctxt, msgid, msgid_plural, n, bindings)
      when is_list(bindings) do
    dpngettext(backend, domain, msgctxt, msgid, msgid_plural, n, Map.new(bindings))
  end

  def dpngettext(backend, domain, msgctxt, msgid, msgid_plural, n, bindings)
      when is_atom(backend) and is_binary(domain) and is_binary(msgid) and is_binary(msgid_plural) and
             is_integer(n) and n >= 0 and is_map(bindings) do
    locale = get_locale(backend)
    result = backend.lngettext(locale, domain, msgctxt, msgid, msgid_plural, n, bindings)
    handle_backend_result(result, backend, locale, domain, msgctxt, msgid)
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
  def dngettext(backend, domain, msgid, msgid_plural, n, bindings),
    do: dpngettext(backend, domain, nil, msgid, msgid_plural, n, bindings)

  @doc """
  Returns the pluralized translation of the given string with a given context
  in the `"default"` domain.

  Works exactly like:

      Gettext.dpngettext(backend, "default", context, msgid, msgid_plural, n, bindings)

  """
  @spec pngettext(module, binary, binary, binary, non_neg_integer, bindings) :: binary
  def pngettext(backend, msgctxt, msgid, msgid_plural, n, bindings),
    do: dpngettext(backend, "default", msgctxt, msgid, msgid_plural, n, bindings)

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

  @doc """
  Runs `fun` with the global Gettext locale set to `locale`.

  This function just sets the global Gettext locale to `locale` before running
  `fun` and sets it back to its previous value afterwards. Note that
  `put_locale/2` is used to set the locale, which is thus set only for the
  current process (keep this in mind if you plan on spawning processes inside
  `fun`).

  The value returned by this function is the return value of `fun`.

  ## Examples

      Gettext.put_locale("fr")

      MyApp.Gettext.gettext("Hello world")
      #=> "Bonjour monde"

      Gettext.with_locale("it", fn ->
        MyApp.Gettext.gettext("Hello world")
      end)
      #=> "Ciao mondo"

      MyApp.Gettext.gettext("Hello world")
      #=> "Bonjour monde"

  """
  @spec with_locale(locale, (() -> result)) :: result when result: var
  def with_locale(locale, fun) do
    previous_locale = Process.get(Gettext)
    Gettext.put_locale(locale)

    try do
      fun.()
    after
      if previous_locale do
        Gettext.put_locale(previous_locale)
      else
        Process.delete(Gettext)
      end
    end
  end

  @doc """
  Runs `fun` with the Gettext locale set to `locale` for the given `backend`.

  This function just sets the Gettext locale for `backend` to `locale` before
  running `fun` and sets it back to its previous value afterwards. Note that
  `put_locale/2` is used to set the locale, which is thus set only for the
  current process (keep this in mind if you plan on spawning processes inside
  `fun`).

  The value returned by this function is the return value of `fun`.

  ## Examples

      Gettext.put_locale(MyApp.Gettext, "fr")

      MyApp.Gettext.gettext("Hello world")
      #=> "Bonjour monde"

      Gettext.with_locale(MyApp.Gettext, "it", fn ->
        MyApp.Gettext.gettext("Hello world")
      end)
      #=> "Ciao mondo"

      MyApp.Gettext.gettext("Hello world")
      #=> "Bonjour monde"

  """
  @spec with_locale(backend, locale, (() -> result)) :: result when result: var
  def with_locale(backend, locale, fun) do
    previous_locale = Process.get(backend)
    Gettext.put_locale(backend, locale)

    try do
      fun.()
    after
      if previous_locale do
        Gettext.put_locale(backend, previous_locale)
      else
        Process.delete(backend)
      end
    end
  end

  @doc """
  Returns all the locales for which PO files exist for the given `backend`.

  If the translations directory for the given backend doesn't exist, then an
  empty list is returned.

  ## Examples

  With the following backend:

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app
      end

  and the following translations directory:

      my_app/priv/gettext
      ├─ en
      ├─ it
      └─ pt_BR

  then:

      Gettext.known_locales(MyApp.Gettext)
      #=> ["en", "it", "pt_BR"]

  """
  @spec known_locales(backend) :: [locale]
  def known_locales(backend) do
    backend.__gettext__(:known_locales)
  end

  defp handle_backend_result({:ok, string}, _backend, _locale, _domain, _msgctxt, _msgid) do
    string
  end

  defp handle_backend_result({:default, string}, _backend, _locale, _domain, _msgctxt, _msgid) do
    string
  end

  defp handle_backend_result(
         {:missing_bindings, incomplete, missing},
         backend,
         locale,
         domain,
         msgctxt,
         msgid
       ) do
    exception = %MissingBindingsError{
      backend: backend,
      locale: locale,
      domain: domain,
      msgctxt: msgctxt,
      msgid: msgid,
      missing: missing
    }

    backend.handle_missing_bindings(exception, incomplete)
  end

  defp handle_backend_result({:error, reason}, _backend, _locale, _domain, _msgctxt, _msgid) do
    raise Error, reason
  end
end
