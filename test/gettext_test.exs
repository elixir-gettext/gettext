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
    assert Translator.lngettext("it", "not a domain", "foo", "foos", 10)
           == {:default, "foo"}
  end
end
