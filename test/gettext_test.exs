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
    assert Translator.lgettext("it_IT", "default", "Hello world")
           == {:ok, "Ciao mondo"}
    assert Translator.lgettext("it_IT", "errors", "Invalid email address")
           == {:ok, "Indirizzo email non valido"}
  end

  test "non-found translations return the argument message" do
    # Unknown msgid.
    assert Translator.lgettext("it_IT", "default", "nonexistent")
           == {:default, "nonexistent"}
    # Unknown domain.
    assert Translator.lgettext("it_IT", "unknown", "Hello world")
           == {:default, "Hello world"}
    # Unknown locale.
    assert Translator.lgettext("pt_BR", "nonexistent", "Hello world")
           == {:default, "Hello world"}
  end

  test "a custom 'priv' directory can be used to store translations" do
    assert TranslatorWithCustomPriv.lgettext("it_IT", "default", "Hello world")
           == {:ok, "Ciao mondo"}
    assert TranslatorWithCustomPriv.lgettext("it_IT", "errors", "Invalid email address")
           == {:ok, "Indirizzo email non valido"}
  end
end
