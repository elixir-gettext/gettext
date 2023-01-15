defmodule GettextTest.Translator do
  use Gettext, otp_app: :test_application, priv: "test/fixtures/single_messages"
end

defmodule GettextTest.TranslatorWithAllowedLocalesString do
  use Gettext,
    otp_app: :test_application,
    priv: "test/fixtures/multi_messages",
    allowed_locales: ["es"]
end

defmodule GettextTest.TranslatorWithAllowedLocalesAtom do
  use Gettext,
    otp_app: :test_application,
    priv: "test/fixtures/multi_messages",
    allowed_locales: [:es]
end

defmodule GettextTest.TranslatorWithCustomPluralForms do
  use Gettext,
    otp_app: :test_application,
    priv: "test/fixtures/single_messages",
    plural_forms: GettextTest.CustomPlural
end

defmodule GettextTest.TranslatorWithCustomCompiledPluralForms do
  use Gettext,
    otp_app: :test_application,
    priv: "test/fixtures/single_messages",
    plural_forms: GettextTest.CustomCompiledPlural
end

defmodule GettextTest.TranslatorWithDefaultDomain do
  use Gettext,
    otp_app: :test_application,
    priv: "test/fixtures/single_messages",
    default_domain: "errors"
end

defmodule GettextTest.HandleMissingMessage do
  use Gettext, otp_app: :test_application, priv: "test/fixtures/single_messages"

  def handle_missing_translation(locale, domain, msgctxt, msgid, bindings) do
    send(self(), {locale, domain, msgctxt, msgid, bindings})
    super(locale, domain, msgctxt, msgid, bindings)
  end

  def handle_missing_plural_translation(locale, domain, msgctxt, msgid, msgid_plural, n, bindings) do
    send(self(), {locale, domain, msgctxt, msgid, msgid_plural, n, bindings})
    super(locale, domain, msgctxt, msgid, msgid_plural, n, bindings)
  end
end

defmodule GettextTest.TranslatorWithDuckInterpolator.Interpolator do
  @behaviour Gettext.Interpolation

  @impl Gettext.Interpolation
  def runtime_interpolate(message, bindings),
    do: {:ok, "quack #{message} #{inspect(bindings)} quack"}

  @impl Gettext.Interpolation
  defmacro compile_interpolate(_message_type, message, bindings) do
    quote do
      {:ok, "quack #{unquote(message)} #{inspect(unquote(bindings))} quack"}
    end
  end

  @impl Gettext.Interpolation
  def message_format, do: "duck-format"
end

defmodule GettextTest.TranslatorWithDuckInterpolator do
  use Gettext,
    otp_app: :test_application,
    interpolation: GettextTest.TranslatorWithDuckInterpolator.Interpolator,
    priv: "test/fixtures/single_messages"
end

defmodule GettextTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias GettextTest.Translator
  alias GettextTest.TranslatorWithAllowedLocalesString
  alias GettextTest.TranslatorWithAllowedLocalesAtom
  alias GettextTest.TranslatorWithCustomCompiledPluralForms
  alias GettextTest.TranslatorWithCustomPluralForms
  alias GettextTest.TranslatorWithDefaultDomain
  alias GettextTest.HandleMissingMessage

  require Translator
  require TranslatorWithDefaultDomain

  test "the default locale is \"en\"" do
    assert Gettext.get_locale() == "en"
    assert Gettext.get_locale(Translator) == "en"
  end

  test "get_locale/0,1 and put_locale/1,2: setting/getting the locale" do
    # First, we set the local for just one backend:
    Gettext.put_locale(Translator, "pt_BR")

    # Now, let's check that only that backend was affected.
    assert Gettext.get_locale(Translator) == "pt_BR"
    assert Gettext.get_locale() == "en"

    # Now, let's change the global locale:
    Gettext.put_locale("it")

    # Let's check that the global locale was affected and that get_locale/1
    # returns the global locale, but only for backends that have no
    # backend-specific locale set.
    assert Gettext.get_locale() == "it"
    assert Gettext.get_locale(Translator) == "pt_BR"
  end

  test "get_locale/0,1: using the default locales" do
    global_default = Application.get_env(:gettext, :default_locale)

    try do
      Application.put_env(:gettext, :default_locale, "fr")
      assert Gettext.get_locale() == "fr"
      assert Gettext.get_locale(Translator) == "fr"
    after
      Application.put_env(:gettext, :default_locale, global_default)
    end
  end

  test "put_locale/2: only accepts binaries" do
    msg = "put_locale/2 only accepts binary locales, got: :en"

    assert_raise ArgumentError, msg, fn ->
      Gettext.put_locale(Translator, :en)
    end
  end

  test "__gettext__(:priv): returns the directory where the messages are stored" do
    assert Translator.__gettext__(:priv) == "test/fixtures/single_messages"
  end

  test "__gettext__(:otp_app): returns the otp app for the given backend" do
    assert Translator.__gettext__(:otp_app) == :test_application
  end

  test "__gettext__(:default_domain): returns the default domain for the given backend" do
    assert Translator.__gettext__(:default_domain) == "default"
    assert TranslatorWithDefaultDomain.__gettext__(:default_domain) == "errors"
  end

  test "found messages return {:ok, message}" do
    assert Translator.lgettext("it", "default", nil, "Hello world", %{}) == {:ok, "Ciao mondo"}

    assert Translator.lgettext("it", "errors", nil, "Invalid email address", %{}) ==
             {:ok, "Indirizzo email non valido"}
  end

  test "non-found messages return the argument message" do
    # Unknown msgid.
    assert Translator.lgettext("it", "default", nil, "nonexistent", %{}) ==
             {:default, "nonexistent"}

    # Unknown domain.
    assert Translator.lgettext("it", "unknown", nil, "Hello world", %{}) ==
             {:default, "Hello world"}

    # Unknown locale.
    assert Translator.lgettext("pt_BR", "nonexistent", nil, "Hello world", %{}) ==
             {:default, "Hello world"}
  end

  test "messages with empty msgstrs fallback to {:default, _}" do
    assert Translator.lgettext("it", "default", nil, "Empty msgstr!", %{}) ==
             {:default, "Empty msgstr!"}
  end

  test "a custom default_domain can be set for a backend" do
    alias TranslatorWithDefaultDomain, as: T
    Gettext.put_locale("it")
    assert T.gettext("Invalid email address") == "Indirizzo email non valido"
    assert T.gettext("Hello world") == "Hello world"
  end

  test "allowed_locales ignores other locales as strings" do
    require TranslatorWithAllowedLocalesString

    assert TranslatorWithAllowedLocalesString.lgettext("it", "default", nil, "Hello world", %{}) ==
             {:default, "Hello world"}

    assert TranslatorWithAllowedLocalesString.lgettext("es", "default", nil, "Hello world", %{}) ==
             {:ok, "Hola mundo"}
  end

  test "allowed_locales ignores other locales as atom" do
    require TranslatorWithAllowedLocalesAtom

    assert TranslatorWithAllowedLocalesAtom.lgettext("it", "default", nil, "Hello world", %{}) ==
             {:default, "Hello world"}

    assert TranslatorWithAllowedLocalesAtom.lgettext("es", "default", nil, "Hello world", %{}) ==
             {:ok, "Hola mundo"}
  end

  test "using a custom Gettext.Plural module" do
    alias TranslatorWithCustomPluralForms, as: T

    assert T.lngettext("it", "default", nil, "One new email", "%{count} new emails", 1, %{}) ==
             {:ok, "1 nuove email"}

    assert T.lngettext("it", "default", nil, "One new email", "%{count} new emails", 2, %{}) ==
             {:ok, "Una nuova email"}
  end

  test "using a custom Gettext.Plural module with the context parameter" do
    alias TranslatorWithCustomCompiledPluralForms, as: T

    assert T.lngettext("it", "default", nil, "One new email", "%{count} new emails", 1, %{})

    assert_received {:plural_context, %{plural_forms_header: "nplurals=2; plural=(n != 1);"}}
  end

  test "using a custom Gettext.Plural module from app environment" do
    Application.put_env(:gettext, :plural_forms, GettextTest.CustomPlural)

    defmodule TranslatorWithAppPluralForms do
      use Gettext, otp_app: :test_application, priv: "test/fixtures/single_messages"
    end

    alias TranslatorWithAppPluralForms, as: T

    assert T.lngettext("it", "default", nil, "One new email", "%{count} new emails", 1, %{}) ==
             {:ok, "1 nuove email"}

    assert T.lngettext("it", "default", nil, "One new email", "%{count} new emails", 2, %{}) ==
             {:ok, "Una nuova email"}
  after
    Application.put_env(:gettext, :plural_forms, Gettext.Plural)
  end

  test "messages can be pluralized" do
    import Translator, only: [lngettext: 7]

    message =
      lngettext("it", "errors", nil, "There was an error", "There were %{count} errors", 1, %{})

    assert message == {:ok, "C'è stato un errore"}

    message =
      lngettext("it", "errors", nil, "There was an error", "There were %{count} errors", 3, %{})

    assert message == {:ok, "Ci sono stati 3 errori"}
  end

  test "by default, non-found pluralized message behave like regular message" do
    assert Translator.lngettext("it", "not a domain", nil, "foo", "foos", 1, %{}) ==
             {:default, "foo"}

    assert Translator.lngettext("it", "not a domain", nil, "foo", "foos", 10, %{}) ==
             {:default, "foos"}
  end

  test "plural messages with empty msgstrs fallback to {:default, _}" do
    msgid = "Not even one msgstr"
    msgid_plural = "Not even %{count} msgstrs"

    assert Translator.lngettext("it", "default", nil, msgid, msgid_plural, 1, %{}) ==
             {:default, "Not even one msgstr"}

    assert Translator.lngettext("it", "default", nil, msgid, msgid_plural, 2, %{}) ==
             {:default, "Not even 2 msgstrs"}
  end

  test "an error is raised if a plural message has no plural form for the given locale" do
    log =
      capture_log(fn ->
        Code.eval_quoted(
          quote do
            defmodule BadTranslations do
              use Gettext,
                otp_app: :test_application,
                priv: "test/fixtures/bad_messages"
            end
          end
        )
      end)

    assert log =~ "message is missing plural form 2 which is required by the locale \"ru\""

    msgid = "should be at least %{count} character(s)"
    msgid_plural = "should be at least %{count} character(s)"

    assert_raise Gettext.PluralFormError,
                 ~r/plural form 2 is required for locale \"ru\" but is missing/,
                 fn ->
                   # Dynamic module to avoid warnings.
                   module = BadTranslations
                   module.lngettext("ru", "errors", nil, msgid, msgid_plural, 8, %{})
                 end
  end

  test "interpolation is supported by lgettext" do
    assert Translator.lgettext("it", "interpolations", nil, "Hello %{name}", %{name: "Jane"}) ==
             {:ok, "Ciao Jane"}

    msgid = "My name is %{name} and I'm %{age}"

    assert Translator.lgettext("it", "interpolations", nil, msgid, %{name: "Meg", age: 33}) ==
             {:ok, "Mi chiamo Meg e ho 33 anni"}

    # A map of bindings is supported as well.
    assert Translator.lgettext("it", "interpolations", nil, "Hello %{name}", %{name: "Jane"}) ==
             {:ok, "Ciao Jane"}
  end

  test "interpolation is supported by lngettext" do
    msgid = "There was an error"
    msgid_plural = "There were %{count} errors"

    assert Translator.lngettext("it", "errors", nil, msgid, msgid_plural, 1, %{}) ==
             {:ok, "C'è stato un errore"}

    assert Translator.lngettext("it", "errors", nil, msgid, msgid_plural, 4, %{}) ==
             {:ok, "Ci sono stati 4 errori"}

    msgid = "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"

    assert Translator.lngettext("it", "interpolations", nil, msgid, msgid_plural, 1, %{
             name: "Jane"
           }) ==
             {:ok, "Hai un messaggio, Jane"}

    assert Translator.lngettext("it", "interpolations", nil, msgid, msgid_plural, 0, %{
             name: "Jane"
           }) ==
             {:ok, "Hai 0 messaggi, Jane"}
  end

  test "strings are concatenated before generating function clauses" do
    msgid = "Concatenated and long string"

    assert Translator.lgettext("it", "default", msgid, %{}) ==
             {:ok, "Stringa lunga e concatenata"}

    assert Translator.lgettext("it", "default", nil, msgid, %{}) ==
             {:ok, "Stringa lunga e concatenata"}

    msgid = "A friend"
    msgid_plural = "%{count} friends"

    assert Translator.lngettext("it", "default", nil, msgid, msgid_plural, 1, %{}) ==
             {:ok, "Un amico"}
  end

  test "lgettext/5: default handle_missing_binding preserves key" do
    msgid = "My name is %{name} and I'm %{age}"

    assert Translator.lgettext("it", "interpolations", nil, msgid, %{name: "José"}) ==
             {:missing_bindings, "Mi chiamo José e ho %{age} anni", [:age]}
  end

  test "MissingBindingsError log messages" do
    assert capture_log(fn ->
             Translator.pgettext("test", "Hello %{name}, missing message!", %{})
           end) =~
             "missing Gettext bindings: [:name] (backend GettextTest.Translator," <>
               " locale \"en\", domain \"default\", msgctxt \"test\", msgid \"Hello " <>
               "%{name}, missing message!\")"
  end

  test "lgettext/5: interpolation works when a message is missing" do
    msgid = "Hello %{name}, missing message!"

    assert Translator.lgettext("pl", "foo", nil, msgid, %{name: "Samantha"}) ==
             {:default, "Hello Samantha, missing message!"}

    msgid = "Hello world!"
    assert Translator.lgettext("pl", "foo", nil, msgid, %{}) == {:default, "Hello world!"}

    msgid = "Hello %{name}"

    assert Translator.lgettext("pl", "foo", nil, msgid, %{}) ==
             {:missing_bindings, "Hello %{name}", [:name]}
  end

  test "lgettext/5: fallbacks to handle_missing_translation" do
    msgctxt = "some context"
    msgid = "Hello %{name}"
    bindings = %{name: "Jane"}

    assert HandleMissingMessage.lgettext("pl", "foo", msgctxt, msgid, bindings) ==
             {:default, "Hello Jane"}

    assert_receive {"pl", "foo", ^msgctxt, ^msgid, ^bindings}
  end

  test "lngettext/6: default handle_missing_binding preserves key" do
    msgid = "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"

    assert Translator.lngettext("it", "interpolations", nil, msgid, msgid_plural, 1, %{}) ==
             {:missing_bindings, "Hai un messaggio, %{name}", [:name]}

    assert Translator.lngettext("it", "interpolations", nil, msgid, msgid_plural, 6, %{}) ==
             {:missing_bindings, "Hai 6 messaggi, %{name}", [:name]}
  end

  test "lngettext/6: interpolation works when a message is missing" do
    msgid = "One error"
    msgid_plural = "%{count} errors"

    assert Translator.lngettext("pl", "foo", nil, msgid, msgid_plural, 1, %{}) ==
             {:default, "One error"}

    assert Translator.lngettext("pl", "foo", nil, msgid, msgid_plural, 9, %{}) ==
             {:default, "9 errors"}
  end

  test "lngettext/6: fallbacks to handle_missing_plural_translation if no message is found" do
    msgctxt = "some context"
    msgid = "Hello %{name}"
    msgid_plural = "Hello %{name}"
    bindings = %{name: "Jane"}

    assert HandleMissingMessage.lngettext(
             "pl",
             "foo",
             msgctxt,
             msgid,
             msgid_plural,
             4,
             bindings
           ) ==
             {:default, "Hello Jane"}

    assert_receive {"pl", "foo", ^msgctxt, ^msgid, ^msgid_plural, 4, ^bindings}
  end

  test "dgettext/3: binary msgid at compile-time" do
    Gettext.put_locale(Translator, "it")

    assert Translator.dgettext("errors", "Invalid email address") == "Indirizzo email non valido"
    keys = %{name: "Jim"}
    assert Translator.dgettext("interpolations", "Hello %{name}", keys) == "Ciao Jim"

    log =
      capture_log(fn ->
        assert Translator.dgettext("interpolations", "Hello %{name}") == "Ciao %{name}"
      end)

    assert log =~ ~s/[error] missing Gettext bindings: [:name]/
  end

  # Macros.

  @gettext_msgid "Hello world"

  test "gettext/2: binary-ish msgid at compile-time" do
    Gettext.put_locale(Translator, "it")
    assert Translator.gettext("Hello world") == "Ciao mondo"
    assert Translator.gettext(@gettext_msgid) == "Ciao mondo"
    assert Translator.gettext(~s(Hello world)) == "Ciao mondo"
  end

  test "pgettext/3: test with context based messages" do
    Gettext.put_locale(Translator, "it")
    assert Translator.pgettext("test", @gettext_msgid) == "Ciao mondo"
    assert Translator.pgettext("test", ~s(Hello world)) == "Ciao mondo"
    assert Translator.pgettext("test", "Hello world", %{}) == "Ciao mondo"
    assert Translator.pgettext("test", "Hello %{name}", %{name: "Marco"}) == "Ciao Marco"
    # Missing message
    assert Translator.pgettext("test", "Hello missing", %{}) == "Hello missing"
  end

  test "pgettext/3, pngettext/4: dynamic context raises" do
    code =
      quote do
        require Translator
        context = "test"
        Translator.pgettext(context, "Hello world")
      end

    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:context"
    assert message =~ "Gettext.gettext(GettextTest.Translator, string)"

    code =
      quote do
        require Translator
        context = "test"
        Translator.pngettext(context, "Hello world", "Hello world", 5)
      end

    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:context"
    assert message =~ "Gettext.gettext(GettextTest.Translator, string)"
  end

  test "dpgettext/4, dpngettext/5: dynamic context or dynamic domain raises" do
    code =
      quote do
        require Translator
        context = "test"
        Translator.dpgettext("default", context, "Hello world")
      end

    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:context"
    assert message =~ "Gettext.gettext(GettextTest.Translator, string)"

    code =
      quote do
        require Translator
        domain = "test"
        Translator.dpgettext(domain, "test", "Hello world")
      end

    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:domain"
    assert message =~ "Gettext.gettext(GettextTest.Translator, string)"

    code =
      quote do
        require Translator
        context = "test"
        Translator.dpngettext("default", context, "Hello world", "Hello world", n)
      end

    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:context"
    assert message =~ "Gettext.gettext(GettextTest.Translator, string)"

    code =
      quote do
        require Translator
        domain = "test"
        Translator.dpngettext(domain, "test", "Hello world", "Hello World", n)
      end

    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:domain"
    assert message =~ "Gettext.gettext(GettextTest.Translator, string)"
  end

  test "dpgettext/4: context and domain based messages" do
    Gettext.put_locale(Translator, "it")
    assert Translator.dpgettext("default", "test", "Hello world", %{}) == "Ciao mondo"
  end

  test "dgettext/3 and dngettext/2: non-binary things at compile-time" do
    code =
      quote do
        require Translator
        msgid = "Invalid email address"
        Translator.dgettext("errors", msgid)
      end

    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:msgid"
    assert message =~ "Gettext.gettext(GettextTest.Translator, string)"

    code =
      quote do
        require Translator
        msgid_plural = ~s(foo #{1 + 1} bar)
        Translator.dngettext("default", "foo", msgid_plural, 1)
      end

    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:msgid_plural"
    assert message =~ "Gettext.gettext(GettextTest.Translator, string)"

    code =
      quote do
        require Translator
        domain = "dynamic_domain"
        Translator.dgettext(domain, "hello")
      end

    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:domain"
  end

  test "dngettext/5" do
    Gettext.put_locale(Translator, "it")

    assert Translator.dngettext(
             "interpolations",
             "You have one message, %{name}",
             "You have %{count} messages, %{name}",
             1,
             %{name: "James"}
           ) == "Hai un messaggio, James"

    assert Translator.dngettext(
             "interpolations",
             "You have one message, %{name}",
             "You have %{count} messages, %{name}",
             2,
             %{name: "James"}
           ) == "Hai 2 messaggi, James"

    assert Translator.dngettext(
             "interpolations",
             "Month",
             "%{count} months",
             2
           ) == "2 mesi"
  end

  @ngettext_msgid "One new email"
  @ngettext_msgid_plural "%{count} new emails"

  test "ngettext/4" do
    Gettext.put_locale(Translator, "it")
    assert Translator.ngettext("One new email", "%{count} new emails", 1) == "Una nuova email"
    assert Translator.ngettext("One new email", "%{count} new emails", 2) == "2 nuove email"

    assert Translator.ngettext(@ngettext_msgid, @ngettext_msgid_plural, 1) == "Una nuova email"
    assert Translator.ngettext(@ngettext_msgid, @ngettext_msgid_plural, 2) == "2 nuove email"
  end

  test "pngettext/4" do
    Gettext.put_locale(Translator, "it")

    assert Translator.pngettext("test", "One new email", "%{count} new emails", 1) ==
             "Una nuova test email"

    assert Translator.pngettext("test", "One new email", "%{count} new emails", 2) ==
             "2 nuove test email"

    assert Translator.pngettext("test", @ngettext_msgid, @ngettext_msgid_plural, 1) ==
             "Una nuova test email"

    assert Translator.pngettext("test", @ngettext_msgid, @ngettext_msgid_plural, 2) ==
             "2 nuove test email"
  end

  test "the d?n?gettext macros support a kw list for interpolation" do
    Gettext.put_locale(Translator, "it")
    assert Translator.gettext("%{msg}", msg: "foo") == "foo"
  end

  test "(d)(p)gettext_noop" do
    assert Translator.dpgettext_noop("errors", "test", "Oops") == "Oops"
    assert Translator.dgettext_noop("errors", "Oops") == "Oops"
    assert Translator.gettext_noop("Hello %{name}!") == "Hello %{name}!"
  end

  test "(d)(p)ngettext_noop" do
    assert Translator.dpngettext_noop("errors", "test", "One error", "%{count} errors") ==
             {"One error", "%{count} errors"}

    assert Translator.dngettext_noop("errors", "One error", "%{count} errors") ==
             {"One error", "%{count} errors"}

    assert Translator.ngettext_noop("One message", "%{count} messages") ==
             {"One message", "%{count} messages"}

    assert Translator.pngettext_noop("test", "One message", "%{count} messages") ==
             {"One message", "%{count} messages"}
  end

  # Actual Gettext functions (not the ones generated in the modules that `use
  # Gettext`).

  test "dgettext/4" do
    Gettext.put_locale(Translator, "it")

    msgid = "Invalid email address"
    assert Gettext.dgettext(Translator, "errors", msgid) == "Indirizzo email non valido"

    assert Gettext.dgettext(Translator, "foo", "Foo") == "Foo"

    log =
      capture_log(fn ->
        assert Gettext.dgettext(Translator, "interpolations", "Hello %{name}", %{}) ==
                 "Ciao %{name}"
      end)

    assert log =~ "[error] missing Gettext bindings: [:name]"
  end

  test "gettext/3" do
    Gettext.put_locale(Translator, "it")
    assert Gettext.gettext(Translator, "Hello world") == "Ciao mondo"
    assert Gettext.gettext(Translator, "Nonexistent") == "Nonexistent"
  end

  test "pgettext/3" do
    Gettext.put_locale(Translator, "it")
    assert Gettext.pgettext(Translator, "test", "Hello world") == "Ciao mondo"
    assert Gettext.pgettext(Translator, "test", "Nonexistent") == "Nonexistent"
  end

  test "dngettext/6" do
    Gettext.put_locale(Translator, "it")
    msgid = "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"

    assert Gettext.dngettext(Translator, "interpolations", msgid, msgid_plural, 1, %{name: "Meg"}) ==
             "Hai un messaggio, Meg"

    assert Gettext.dngettext(Translator, "interpolations", msgid, msgid_plural, 5, %{name: "Meg"}) ==
             "Hai 5 messaggi, Meg"

    assert Gettext.dngettext(Translator, "interpolations", "Month", "%{count} months", 5) ==
             "5 mesi"
  end

  test "dpngettext/6" do
    Gettext.put_locale(Translator, "it")
    msgid = "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"

    assert Gettext.dpngettext(Translator, "interpolations", "test", msgid, msgid_plural, 1, %{
             name: "Meg"
           }) ==
             "Hai un messaggio, Meg"

    assert Gettext.dpngettext(Translator, "interpolations", "test", msgid, msgid_plural, 5, %{
             name: "Meg"
           }) ==
             "Hai 5 messaggi, Meg"

    assert Gettext.dpngettext(
             Translator,
             "default",
             "test",
             "One new email",
             "%{count} new emails",
             5,
             %{name: "Meg"}
           ) == "5 nuove test email"
  end

  test "pngettext/6" do
    Gettext.put_locale(Translator, "it")
    msgctxt = "test"
    msgid = "One cake, %{name}"
    msgid_plural = "%{count} cakes, %{name}"

    assert Gettext.pngettext(Translator, msgctxt, msgid, msgid_plural, 1, %{name: "Meg"}) ==
             "One cake, Meg"

    assert Gettext.pngettext(Translator, msgctxt, msgid, msgid_plural, 5, %{name: "Meg"}) ==
             "5 cakes, Meg"
  end

  test "ngettext/5" do
    Gettext.put_locale(Translator, "it")
    msgid = "One cake, %{name}"
    msgid_plural = "%{count} cakes, %{name}"
    assert Gettext.ngettext(Translator, msgid, msgid_plural, 1, %{name: "Meg"}) == "One cake, Meg"
    assert Gettext.ngettext(Translator, msgid, msgid_plural, 5, %{name: "Meg"}) == "5 cakes, Meg"
  end

  test "the d?n?gettext functions support kw list for interpolations" do
    Gettext.put_locale(Translator, "it")
    assert Gettext.gettext(Translator, "Hello %{name}", name: "José") == "Hello José"
  end

  test "with_locale/3 runs a function with a given locale and returns the returned value" do
    Gettext.put_locale(Translator, "fr")
    # no 'fr' message
    assert Gettext.gettext(Translator, "Hello world") == "Hello world"

    res =
      Gettext.with_locale(Translator, "it", fn ->
        assert Gettext.gettext(Translator, "Hello world") == "Ciao mondo"
        :foo
      end)

    assert Gettext.get_locale(Translator) == "fr"
    assert res == :foo
  end

  test "with_locale/3 resets the locale even if the given function raises" do
    Gettext.put_locale(Translator, "fr")

    assert_raise RuntimeError, fn ->
      Gettext.with_locale(Translator, "it", fn -> raise "foo" end)
    end

    assert Gettext.get_locale(Translator) == "fr"

    catch_throw(Gettext.with_locale(Translator, "it", fn -> throw(:foo) end))
    assert Gettext.get_locale(Translator) == "fr"
  end

  test "with_locale/3: doesn't raise if no locale was set (defaulting to 'en')" do
    Process.delete(Translator)

    Gettext.with_locale(Translator, "it", fn ->
      assert Gettext.gettext(Translator, "Hello world") == "Ciao mondo"
    end)

    assert Gettext.get_locale(Translator) == "en"
  end

  test "known_locales/1: returns all the locales for which a backend has PO files" do
    assert Gettext.known_locales(Translator) == ["it"]
    assert Gettext.known_locales(TranslatorWithAllowedLocalesAtom) == ["es"]
    assert Gettext.known_locales(TranslatorWithAllowedLocalesString) == ["es"]
  end

  test "a warning is issued in l(n)gettext when the domain contains slashes" do
    log =
      capture_log(fn ->
        assert Translator.dgettext("sub/dir/domain", "hello") == "hello"
      end)

    assert log =~ ~s(Slashes in domains are not supported: "sub/dir/domain")
  end

  defmodule TranslatorWithOneModulePerLocale do
    use Gettext,
      otp_app: :test_application,
      split_module_by: [:locale],
      split_module_compilation: :parallel,
      priv: "test/fixtures/single_messages"
  end

  test "may define one module per locale" do
    import TranslatorWithOneModulePerLocale, only: [lgettext: 5, lngettext: 7]
    assert Code.ensure_loaded?(TranslatorWithOneModulePerLocale.T_it)

    # Found on default domain.
    assert lgettext("it", "default", nil, "Hello world", %{}) == {:ok, "Ciao mondo"}

    # Found on errors domain.
    assert lgettext("it", "errors", nil, "Invalid email address", %{}) ==
             {:ok, "Indirizzo email non valido"}

    # Found with plural form.
    assert lngettext(
             "it",
             "errors",
             nil,
             "There was an error",
             "There were %{count} errors",
             1,
             %{}
           ) ==
             {:ok, "C'è stato un errore"}

    # Unknown msgid.
    assert lgettext("it", "default", nil, "nonexistent", %{}) == {:default, "nonexistent"}

    # Unknown domain.
    assert lgettext("it", "unknown", nil, "Hello world", %{}) == {:default, "Hello world"}

    # Unknown locale.
    assert lgettext("pt_BR", "nonexistent", nil, "Hello world", %{}) ==
             {:default, "Hello world"}
  end

  defmodule TranslatorWithOneModulePerLocaleDomain do
    use Gettext,
      otp_app: :test_application,
      split_module_by: [:locale, :domain],
      split_module_compilation: :serial,
      priv: "test/fixtures/single_messages"
  end

  test "may define one module per locale and domain" do
    import TranslatorWithOneModulePerLocaleDomain, only: [lgettext: 5, lngettext: 7]
    assert Code.ensure_loaded?(TranslatorWithOneModulePerLocaleDomain.T_it_default)

    # Found on default domain.
    assert lgettext("it", "default", nil, "Hello world", %{}) == {:ok, "Ciao mondo"}

    # Found on errors domain.
    assert lgettext("it", "errors", nil, "Invalid email address", %{}) ==
             {:ok, "Indirizzo email non valido"}

    # Found with plural form.
    assert lngettext(
             "it",
             "errors",
             nil,
             "There was an error",
             "There were %{count} errors",
             1,
             %{}
           ) ==
             {:ok, "C'è stato un errore"}

    # Unknown msgid.
    assert lgettext("it", "default", nil, "nonexistent", %{}) == {:default, "nonexistent"}

    # Unknown domain.
    assert lgettext("it", "unknown", nil, "Hello world", %{}) == {:default, "Hello world"}

    # Unknown locale.
    assert lgettext("pt_BR", "nonexistent", nil, "Hello world", %{}) ==
             {:default, "Hello world"}
  end

  test "uses custom interpolator" do
    import GettextTest.TranslatorWithDuckInterpolator, only: [gettext: 1]

    assert "quack foo %{} quack" = gettext("foo")
  end
end
