defmodule Gettext.MacrosTest.Translator do
  use Gettext.Backend,
    otp_app: :test_application,
    priv: "test/fixtures/single_messages"
end

defmodule Gettext.MacrosTest do
  use ExUnit.Case, async: true
  use Gettext, backend: Gettext.MacrosTest.Translator

  import ExUnit.CaptureLog

  require Gettext.Macros, as: Macros

  @backend Gettext.MacrosTest.Translator
  @gettext_msgid "Hello world"

  describe "gettext/2" do
    test "supports binary-ish msgid at compile-time" do
      Gettext.put_locale(@backend, "it")
      assert gettext("Hello world") == "Ciao mondo"
      assert gettext(@gettext_msgid) == "Ciao mondo"
      assert gettext(~s(Hello world)) == "Ciao mondo"
    end
  end

  describe "dgettext/3" do
    test "supports binary-ish msgid at compile-time" do
      Gettext.put_locale(@backend, "it")

      assert dgettext("errors", "Invalid email address") == "Indirizzo email non valido"
      keys = %{name: "Jim"}
      assert dgettext("interpolations", "Hello %{name}", keys) == "Ciao Jim"

      log =
        capture_log(fn ->
          assert dgettext("interpolations", "Hello %{name}") == "Ciao %{name}"
        end)

      assert log =~ ~s/[error] missing Gettext bindings: [:name]/
    end
  end

  describe "pgettext/3" do
    test "supports test with context based messages" do
      Gettext.put_locale(@backend, "it")
      assert pgettext("test", @gettext_msgid) == "Ciao mondo"
      assert pgettext("test", ~s(Hello world)) == "Ciao mondo"
      assert pgettext("test", "Hello world", %{}) == "Ciao mondo"
      assert pgettext("test", "Hello %{name}", %{name: "Marco"}) == "Ciao Marco"

      # Missing message
      assert pgettext("test", "Hello missing", %{}) == "Hello missing"
    end
  end

  test "pgettext/3, pngettext/4: dynamic context raises" do
    error =
      assert_raise ArgumentError, fn ->
        defmodule Sample do
          use Gettext, backend: Gettext.MacrosTest.Translator
          context = "test"
          pgettext(context, "Hello world")
        end
      end

    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:context"
    assert message =~ "Gettext.gettext(Gettext.MacrosTest.Translator, string)"

    error =
      assert_raise ArgumentError, fn ->
        defmodule Sample do
          use Gettext, backend: Gettext.MacrosTest.Translator
          context = "test"
          pngettext(context, "Hello world", "Hello world", 5)
        end
      end

    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:context"
    assert message =~ "Gettext.gettext(Gettext.MacrosTest.Translator, string)"
  end

  test "dpgettext/4, dpngettext/5: dynamic context or dynamic domain raises" do
    error =
      assert_raise ArgumentError, fn ->
        defmodule Sample do
          use Gettext, backend: Gettext.MacrosTest.Translator
          context = "test"
          dpgettext("default", context, "Hello world")
        end
      end

    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:context"
    assert message =~ "Gettext.gettext(Gettext.MacrosTest.Translator, string)"

    error =
      assert_raise ArgumentError, fn ->
        defmodule Sample do
          use Gettext, backend: Gettext.MacrosTest.Translator
          domain = "test"
          dpgettext(domain, "test", "Hello world")
        end
      end

    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:domain"
    assert message =~ "Gettext.gettext(Gettext.MacrosTest.Translator, string)"

    error =
      assert_raise ArgumentError, fn ->
        defmodule Sample do
          use Gettext, backend: Gettext.MacrosTest.Translator
          context = "test"
          dpngettext("default", context, "Hello world", "Hello world", n)
        end
      end

    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:context"
    assert message =~ "Gettext.gettext(Gettext.MacrosTest.Translator, string)"

    error =
      assert_raise ArgumentError, fn ->
        defmodule Sample do
          use Gettext, backend: Gettext.MacrosTest.Translator
          context = "test"
          dpngettext(domain, "test", "Hello world", "Hello World", n)
        end
      end

    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:domain"
    assert message =~ "Gettext.gettext(Gettext.MacrosTest.Translator, string)"
  end

  test "dpgettext/4: context and domain based messages" do
    Gettext.put_locale(@backend, "it")
    assert dpgettext("default", "test", "Hello world", %{}) == "Ciao mondo"
  end

  test "dgettext/3 and dngettext/2: non-binary things at compile-time" do
    error =
      assert_raise ArgumentError, fn ->
        defmodule Sample do
          use Gettext, backend: Gettext.MacrosTest.Translator
          context = "test"
          dgettext("errors", msgid)
        end
      end

    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:msgid"
    assert message =~ "Gettext.gettext(Gettext.MacrosTest.Translator, string)"

    error =
      assert_raise ArgumentError, fn ->
        defmodule Sample do
          use Gettext, backend: Gettext.MacrosTest.Translator
          msgid_plural = ~s(foo #{1 + 1} bar)
          dngettext("default", "foo", msgid_plural, 1)
        end
      end

    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:msgid_plural"
    assert message =~ "Gettext.gettext(Gettext.MacrosTest.Translator, string)"

    error =
      assert_raise ArgumentError, fn ->
        defmodule Sample do
          use Gettext, backend: Gettext.MacrosTest.Translator
          domain = "dynamic_domain"
          dgettext(domain, "hello")
        end
      end

    message = ArgumentError.message(error)
    assert message =~ "Gettext macros expect message keys"
    assert message =~ "{:domain"
  end

  describe "dngettext/5" do
    test "translates with plural and domain" do
      Gettext.put_locale(@backend, "it")

      assert dngettext(
               "interpolations",
               "You have one message, %{name}",
               "You have %{count} messages, %{name}",
               1,
               %{name: "James"}
             ) == "Hai un messaggio, James"

      assert dngettext(
               "interpolations",
               "You have one message, %{name}",
               "You have %{count} messages, %{name}",
               2,
               %{name: "James"}
             ) == "Hai 2 messaggi, James"

      assert dngettext(
               "interpolations",
               "Month",
               "%{count} months",
               2
             ) == "2 mesi"
    end
  end

  @ngettext_msgid "One new email"
  @ngettext_msgid_plural "%{count} new emails"

  describe "ngettext/4" do
    test "translates with plural" do
      Gettext.put_locale(@backend, "it")
      assert ngettext("One new email", "%{count} new emails", 1) == "Una nuova email"
      assert ngettext("One new email", "%{count} new emails", 2) == "2 nuove email"

      assert ngettext(@ngettext_msgid, @ngettext_msgid_plural, 1) == "Una nuova email"
      assert ngettext(@ngettext_msgid, @ngettext_msgid_plural, 2) == "2 nuove email"
    end
  end

  describe "pngettext/4" do
    test "translates with plurals and context" do
      Gettext.put_locale(@backend, "it")

      assert pngettext("test", "One new email", "%{count} new emails", 1) ==
               "Una nuova test email"

      assert pngettext("test", "One new email", "%{count} new emails", 2) ==
               "2 nuove test email"

      assert pngettext("test", @ngettext_msgid, @ngettext_msgid_plural, 1) ==
               "Una nuova test email"

      assert pngettext("test", @ngettext_msgid, @ngettext_msgid_plural, 2) ==
               "2 nuove test email"
    end
  end

  test "the d?n?gettext macros support a kw list for interpolation" do
    Gettext.put_locale(@backend, "it")
    assert gettext("%{msg}", msg: "foo") == "foo"
  end

  test "(d)(p)gettext_noop" do
    assert dpgettext_noop("errors", "test", "Oops") == "Oops"
    assert dgettext_noop("errors", "Oops") == "Oops"
    assert gettext_noop("Hello %{name}!") == "Hello %{name}!"
  end

  test "(d)(p)ngettext_noop" do
    assert dpngettext_noop("errors", "test", "One error", "%{count} errors") ==
             {"One error", "%{count} errors"}

    assert dngettext_noop("errors", "One error", "%{count} errors") ==
             {"One error", "%{count} errors"}

    assert ngettext_noop("One message", "%{count} messages") ==
             {"One message", "%{count} messages"}

    assert pngettext_noop("test", "One message", "%{count} messages") ==
             {"One message", "%{count} messages"}
  end

  ## _with_backend variants

  describe "dpgettext_noop_with_backend/4" do
    test "supports test with context based messages" do
      assert Macros.dpgettext_noop_with_backend(@backend, "test", "ctx", "Hello world") ==
               "Hello world"
    end
  end

  describe "dgettext_noop_with_backend/4" do
    test "supports test with context based messages" do
      assert Macros.dgettext_noop_with_backend(@backend, "test", "Hello world") == "Hello world"
    end
  end

  describe "pgettext_noop_with_backend/4" do
    test "supports test with context based messages" do
      assert Macros.pgettext_noop_with_backend(@backend, "ctx", "Hello world") == "Hello world"
    end
  end

  describe "gettext_noop_with_backend/2" do
    test "supports test with context based messages" do
      assert Macros.gettext_noop_with_backend(@backend, "Hello world") == "Hello world"
    end
  end

  describe "dpngettext_noop_with_backend/5" do
    test "supports test with context based messages" do
      assert Macros.dpngettext_noop_with_backend(
               @backend,
               "test",
               "ctx",
               "One message",
               "%{count} messages"
             ) ==
               {"One message", "%{count} messages"}
    end
  end

  describe "dngettext_noop_with_backend/4" do
    test "supports test with context based messages" do
      assert Macros.dngettext_noop_with_backend(
               @backend,
               "test",
               "One message",
               "%{count} messages"
             ) ==
               {"One message", "%{count} messages"}
    end
  end

  describe "pngettext_noop_with_backend/4" do
    test "supports test with context based messages" do
      assert Macros.pngettext_noop_with_backend(
               @backend,
               "ctx",
               "One message",
               "%{count} messages"
             ) ==
               {"One message", "%{count} messages"}
    end
  end

  describe "ngettext_noop_with_backend/3" do
    test "supports test with context based messages" do
      assert Macros.ngettext_noop_with_backend(@backend, "One message", "%{count} messages") ==
               {"One message", "%{count} messages"}
    end
  end

  describe "translation macros *_with_backend" do
    setup do
      Gettext.put_locale(@backend, "it")
      :ok
    end

    test "dpgettext_with_backend/5" do
      assert Macros.dpgettext_with_backend(@backend, "default", "test", "Hello world", %{}) ==
               "Ciao mondo"
    end

    test "dgettext_with_backend/4" do
      assert Macros.dgettext_with_backend(@backend, "default", "Hello world") == "Ciao mondo"
    end

    test "pgettext_with_backend/4" do
      assert Macros.pgettext_with_backend(@backend, "test", "Hello world") == "Ciao mondo"
    end

    test "gettext_with_backend/2" do
      assert Macros.gettext_with_backend(@backend, "Hello world") == "Ciao mondo"
    end

    test "dpngettext_with_backend/6" do
      assert Macros.dpngettext_with_backend(
               @backend,
               "default",
               "test",
               "One new email",
               "%{count} new emails",
               1
             ) == "Una nuova test email"
    end

    test "dngettext_with_backend/5" do
      assert Macros.dngettext_with_backend(
               @backend,
               "default",
               "One new email",
               "%{count} new emails",
               1
             ) == "Una nuova email"
    end

    test "pngettext_with_backend/5" do
      assert Macros.pngettext_with_backend(
               @backend,
               "test",
               "One new email",
               "%{count} new emails",
               1
             ) == "Una nuova test email"
    end

    test "ngettext_with_backend/4" do
      assert Macros.ngettext_with_backend(
               @backend,
               "One new email",
               "%{count} new emails",
               1
             ) == "Una nuova email"
    end
  end
end
