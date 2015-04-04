defmodule GettextTest do
  use ExUnit.Case, async: true

  # Dynamically load dummy apps which just have an `ebin/` directory and
  # translations.
  for app <- ["default_priv", "custom_priv"] do
    [__DIR__, "fixtures", "test_applications", app, "ebin"]
    |> Path.join
    |> Code.prepend_path
  end

  defmodule Translator do
    use Gettext, otp_app: :default_priv
  end

  defmodule TranslatorWithCustomPriv do
    use Gettext, otp_app: :custom_priv, priv: "translations"
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
