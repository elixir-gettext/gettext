defmodule GettextTest do
  use ExUnit.Case, async: true

  # Let's load the test application.
  [__DIR__, "fixtures", "test_application", "ebin"]
  |> Path.join
  |> Code.prepend_path

  defmodule Translator do
    use Gettext, otp_app: :test_application
  end

  defmodule TranslatorWithCustomPriv do
    use Gettext, otp_app: :test_application, priv: "translations"
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
    assert Translator.lgettext("it", "interpolations", "Hello %{name}", name: "Jane")
           == {:ok, "Ciao Jane"}

    msgid = "My name is %{name} and I'm %{age}"
    assert Translator.lgettext("it", "interpolations", msgid, name: "Meg", age: 33)
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
    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 1, name: "Jane")
           == {:ok, "Hai un messaggio, Jane"}
    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 0, %{name: "Jane"})
           == {:ok, "Hai 0 messaggi, Jane"}
  end

  test "when keys are missing in an interpolation, an error is returned" do
    msgid = "My name is %{name} and I'm %{age}"
    assert Translator.lgettext("it", "interpolations", msgid, name: "José")
           == {:error, "missing interpolation keys: age"}
  end

  test "lgettext/4: interpolation works when a translation is missing" do
    msgid = "Hello %{name}, missing translation!"
    assert Translator.lgettext("pl", "foo", msgid, name: "Samantha")
           == {:default, "Hello Samantha, missing translation!"}

    msgid = "Hello world!"
    assert Translator.lgettext("pl", "foo", msgid)
           == {:default, "Hello world!"}

    msgid = "Hello %{name}"
    assert Translator.lgettext("pl", "foo", msgid, %{})
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
end
