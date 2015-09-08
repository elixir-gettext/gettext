defmodule GettextTest.Translator do
  use Gettext, otp_app: :test_application
end

defmodule GettextTest.TranslatorWithCustomPriv do
  use Gettext, otp_app: :test_application, priv: "translations"
end

defmodule GettextTest do
  use ExUnit.Case, async: true

  alias GettextTest.Translator
  alias GettextTest.TranslatorWithCustomPriv
  require Translator
  require TranslatorWithCustomPriv

  test "the default locale is \"en\"" do
    assert Gettext.locale == "en"
  end

  test "locale/0-1: sets and gets the locale" do
    Gettext.locale("pt_BR")
    assert Gettext.locale == "pt_BR"
  end

  test "locale/0-1: only accepts binaries" do
    assert_raise ArgumentError, "locale/1 only accepts binary locales", fn ->
      Gettext.locale :en
    end
  end

  test "__gettext__(:priv): returns the directory where the translations are stored" do
    assert GettextTest.Translator.__gettext__(:priv) == "priv/gettext"
    assert GettextTest.TranslatorWithCustomPriv.__gettext__(:priv) == "translations"
  end

  test "found translations return {:ok, translation}" do
    assert Translator.lgettext("it", "default", "Hello world")
           == {:ok, "Ciao mondo"}

    assert Translator.lgettext("it", "errors", "Invalid email address")
           == {:ok, "Indirizzo email non valido"}
  end

  test "non-found translations return the argument message" do
    # Unknown msgid.
    assert Translator.lgettext("it", "default", "nonexistent")
           == {:default, "nonexistent"}

    # Unknown domain.
    assert Translator.lgettext("it", "unknown", "Hello world")
           == {:default, "Hello world"}

    # Unknown locale.
    assert Translator.lgettext("pt_BR", "nonexistent", "Hello world")
           == {:default, "Hello world"}
  end

  test "a custom 'priv' directory can be used to store translations" do
    assert TranslatorWithCustomPriv.lgettext("it", "default", "Hello world")
           == {:ok, "Ciao mondo"}

    assert TranslatorWithCustomPriv.lgettext("it", "errors", "Invalid email address")
           == {:ok, "Indirizzo email non valido"}
  end

  test "translations can be pluralized" do
    import Translator, only: [lngettext: 5]

    t = lngettext("it", "errors", "There was an error", "There were %{count} errors", 1)
    assert t == {:ok, "C'è stato un errore"}

    t = lngettext("it", "errors", "There was an error", "There were %{count} errors", 3)
    assert t == {:ok, "Ci sono stati 3 errori"}
  end

  test "by default, non-found pluralized translation behave like regular translation" do
    assert Translator.lngettext("it", "not a domain", "foo", "foos", 1)
           == {:default, "foo"}
    assert Translator.lngettext("it", "not a domain", "foo", "foos", 10)
           == {:default, "foos"}
  end

  test "interpolation is supported by lgettext" do
    assert Translator.lgettext("it", "interpolations", "Hello %{name}", %{name: "Jane"})
           == {:ok, "Ciao Jane"}

    msgid = "My name is %{name} and I'm %{age}"
    assert Translator.lgettext("it", "interpolations", msgid, %{name: "Meg", age: 33})
           == {:ok, "Mi chiamo Meg e ho 33 anni"}

    # A map of bindings is supported as well.
    assert Translator.lgettext("it", "interpolations", "Hello %{name}", %{name: "Jane"})
           == {:ok, "Ciao Jane"}
  end

  test "interpolation is supported by lngettext" do
    msgid        = "There was an error"
    msgid_plural = "There were %{count} errors"
    assert Translator.lngettext("it", "errors", msgid, msgid_plural, 1)
           == {:ok, "C'è stato un errore"}
    assert Translator.lngettext("it", "errors", msgid, msgid_plural, 4)
           == {:ok, "Ci sono stati 4 errori"}

    msgid        = "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"
    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 1, %{name: "Jane"})
           == {:ok, "Hai un messaggio, Jane"}
    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 0, %{name: "Jane"})
           == {:ok, "Hai 0 messaggi, Jane"}
  end

  test "strings are concatenated before generating function clauses" do
    msgid = "Concatenated and long string"
    assert Translator.lgettext("it", "default", msgid)
           == {:ok, "Stringa lunga e concatenata"}

    msgid        = "A friend"
    msgid_plural = "%{count} friends"
    assert Translator.lngettext("it", "default", msgid, msgid_plural, 1, %{})
           == {:ok, "Un amico"}
  end

  test "lgettext/4: error when keys are missing in an interpolation" do
    msgid = "My name is %{name} and I'm %{age}"
    assert Translator.lgettext("it", "interpolations", msgid, name: "José")
           == {:error, "missing interpolation keys: age"}
  end

  test "lgettext/4: interpolation works when a translation is missing" do
    msgid = "Hello %{name}, missing translation!"
    assert Translator.lgettext("pl", "foo", msgid, %{name: "Samantha"})
           == {:default, "Hello Samantha, missing translation!"}

    msgid = "Hello world!"
    assert Translator.lgettext("pl", "foo", msgid)
           == {:default, "Hello world!"}

    msgid = "Hello %{name}"
    assert Translator.lgettext("pl", "foo", msgid, %{})
           == {:error, "missing interpolation keys: name"}
  end

  test "lngettext/6: error when keys are missing in an interpolation" do
    msgid =  "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"

    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 1)
           == {:error, "missing interpolation keys: name"}

    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 6)
           == {:error, "missing interpolation keys: name"}
  end

  test "lngettext/6: interpolation works when a translation is missing" do
    msgid        = "One error"
    msgid_plural = "%{count} errors"
    assert Translator.lngettext("pl", "foo", msgid, msgid_plural, 1)
           == {:default, "One error"}
    assert Translator.lngettext("pl", "foo", msgid, msgid_plural, 9)
           == {:default, "9 errors"}
  end

  test "dgettext/3: binary msgid at compile-time" do
    Gettext.locale "it"

    assert Translator.dgettext("errors", "Invalid email address")
           == "Indirizzo email non valido"
    keys = %{name: "Jim"}
    assert Translator.dgettext("interpolations", "Hello %{name}", keys)
           == "Ciao Jim"

    msg = "missing interpolation keys: name"
    assert_raise Gettext.Error, msg, fn ->
      Translator.dgettext("interpolations", "Hello %{name}")
    end
  end

  # Macros.

  @gettext_msgid "Hello world"

  test "gettext/2: binary-ish msgid at compile-time" do
    Gettext.locale "it"
    assert Translator.gettext("Hello world") == "Ciao mondo"
    assert Translator.gettext(@gettext_msgid) == "Ciao mondo"
  end

  test "dgettext/3 and gettext/2: non-binary msgid at compile-time" do
    code = quote do
      require Translator
      msgid = "Invalid email address"
      Translator.dgettext("errors", msgid)
    end
    assert_raise ArgumentError, "msgid must be a string literal", fn ->
      Code.eval_quoted code
    end

    code = quote do
      require Translator
      msgid = "Hello world"
      Translator.gettext(msgid)
    end
    assert_raise ArgumentError, "msgid must be a string literal", fn ->
      Code.eval_quoted code
    end
  end

  test "dngettext/5" do
    Gettext.locale "it"
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
  end

  test "dngettext/5: non-literal string arguments" do
    code = quote do
      require Translator
      msgid_plural = "foos"
      Translator.dngettext("foo", "foo", msgid_plural, 4)
    end
    assert_raise ArgumentError, "msgid and msgid_plural must be string literals", fn ->
      Code.eval_quoted code
    end
  end

  @ngettext_msgid "One new email"
  @ngettext_msgid_plural "%{count} new emails"

  test "ngettext/4" do
    Gettext.locale "it"
    assert Translator.ngettext("One new email", "%{count} new emails", 1)
           == "Una nuova email"
    assert Translator.ngettext("One new email", "%{count} new emails", 2)
           == "2 nuove email"

    assert Translator.ngettext(@ngettext_msgid, @ngettext_msgid_plural, 1)
           == "Una nuova email"
    assert Translator.ngettext(@ngettext_msgid, @ngettext_msgid_plural, 2)
           == "2 nuove email"
  end

  test "the d?n?gettext macros support a kw list for interpolation" do
    Gettext.locale "it"
    assert Translator.gettext("%{msg}", msg: "foo") == "foo"
  end


  # Actual Gettext functions (not the ones generated in the modules that `use
  # Gettext`).

  test "dgettext/4" do
    Gettext.locale "it"

    msgid = "Invalid email address"
    assert Gettext.dgettext(Translator, "errors", msgid)
           == "Indirizzo email non valido"

    assert Gettext.dgettext(Translator, "foo", "Foo") == "Foo"

    msg = "missing interpolation keys: name"
    assert_raise Gettext.Error, msg, fn ->
      Gettext.dgettext(Translator, "interpolations", "Hello %{name}", %{})
    end
  end

  test "gettext/3" do
    Gettext.locale "it"
    assert Gettext.gettext(Translator, "Hello world") == "Ciao mondo"
    assert Gettext.gettext(Translator, "Nonexistent") == "Nonexistent"
  end

  test "dngettext/6" do
    Gettext.locale "it"
    msgid        = "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"
    assert Gettext.dngettext(Translator, "interpolations", msgid, msgid_plural, 1, %{name: "Meg"})
           == "Hai un messaggio, Meg"
    assert Gettext.dngettext(Translator, "interpolations", msgid, msgid_plural, 5, %{name: "Meg"})
           == "Hai 5 messaggi, Meg"
  end

  test "ngettext/5" do
    Gettext.locale "it"
    msgid        = "One cake, %{name}"
    msgid_plural = "%{count} cakes, %{name}"
    assert Gettext.ngettext(Translator, msgid, msgid_plural, 1, %{name: "Meg"})
           == "One cake, Meg"
    assert Gettext.ngettext(Translator, msgid, msgid_plural, 5, %{name: "Meg"})
           == "5 cakes, Meg"
  end

  test "the d?n?gettext functions support kw list for interpolations" do
    Gettext.locale "it"
    assert Gettext.gettext(Translator, "Hello %{name}", name: "José") == "Hello José"
  end

  test "with_locale/2 runs a function with a given locale and returns the returned value" do
    Gettext.locale "fr"
    assert Gettext.gettext(Translator, "Hello world") == "Hello world" # no 'fr' translation
    res = Gettext.with_locale "it", fn ->
      assert Gettext.gettext(Translator, "Hello world") == "Ciao mondo"
      :foo
    end

    assert res == :foo
  end

  test "with_locale/2 resets the locale even if the given function raises" do
    Gettext.locale "fr"

    assert_raise RuntimeError, fn ->
      Gettext.with_locale "it", fn -> raise "foo" end
    end
    assert Gettext.locale == "fr"

    catch_throw(Gettext.with_locale "it", fn -> throw :foo end)
    assert Gettext.locale == "fr"
  end
end
