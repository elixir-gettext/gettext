defmodule Gettext.BackendTest do
  # Some things change the :gettext app environment.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias GettextTest.{
    Backend,
    BackendWithDefaultDomain
  }

  defmodule BackendWithCustomPluralForms do
    use Gettext.Backend,
      otp_app: :test_application,
      priv: "test/fixtures/single_messages",
      plural_forms: GettextTest.CustomPlural
  end

  defmodule BackendWithCustomCompiledPluralForms do
    use Gettext.Backend,
      otp_app: :test_application,
      priv: "test/fixtures/single_messages",
      plural_forms: GettextTest.CustomCompiledPlural
  end

  defmodule BackendWithOneModulePerLocale do
    use Gettext.Backend,
      otp_app: :test_application,
      split_module_by: [:locale],
      split_module_compilation: :parallel,
      priv: "test/fixtures/single_messages"
  end

  defmodule BackendWithOneModulePerLocaleDomain do
    use Gettext.Backend,
      otp_app: :test_application,
      split_module_by: [:locale, :domain],
      split_module_compilation: :serial,
      priv: "test/fixtures/single_messages"
  end

  describe "use Gettext.Backend" do
    test "creates a backend" do
      body =
        quote do
          use Gettext.Backend,
            otp_app: :test_application
        end

      {:module, mod, _bytecode, :ok} = Module.create(TestBackend, body, __ENV__)

      assert mod.__gettext__(:otp_app) == :test_application
      assert mod.__info__(:attributes)[:behaviour] == [Gettext.Backend]
    end

    test "may define one module per locale" do
      import BackendWithOneModulePerLocale, only: [lgettext: 5, lngettext: 7]
      assert Code.ensure_loaded?(BackendWithOneModulePerLocale.T_it)

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

    test "may define one module per locale and domain" do
      import BackendWithOneModulePerLocaleDomain, only: [lgettext: 5, lngettext: 7]
      assert Code.ensure_loaded?(BackendWithOneModulePerLocaleDomain.T_it_default)

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
  end

  describe "compiling catalogs of different shapes" do
    @tag :tmp_dir
    test "compiles without warnings and looks translations up by context", %{tmp_dir: tmp_dir} do
      catalogs = [
        static_only: ~S"""
        msgid "Hello world"
        msgstr "Ciao mondo"

        msgctxt ""
        msgid "Empty context"
        msgstr "Contesto vuoto"

        msgctxt "greeting"
        msgid "Hello world"
        msgstr "Ciao mondo (saluto)"

        #~ msgid "Gone"
        #~ msgstr "Andato"
        """,
        interpolated_only: ~S"""
        msgid "Hello %{name}"
        msgstr "Ciao %{name}"
        """,
        plural_only: ~S"""
        msgid "One new email"
        msgid_plural "%{count} new emails"
        msgstr[0] "Una nuova email"
        msgstr[1] "%{count} nuove email"
        """
      ]

      backends =
        for {shape, contents} <- catalogs, into: %{} do
          priv = Path.join(tmp_dir, "#{shape}")
          po_file = Path.join([priv, "it", "LC_MESSAGES", "default.po"])
          File.mkdir_p!(Path.dirname(po_file))
          File.write!(po_file, contents)

          module =
            Module.concat(__MODULE__, "Backend#{shape}#{System.unique_integer([:positive])}")

          source = Path.join(tmp_dir, "#{shape}.ex")

          File.write!(source, """
          defmodule #{inspect(module)} do
            use Gettext.Backend, otp_app: :test_application, priv: #{inspect(priv)}
          end
          """)

          # Compiled through the parallel compiler like a Mix project is, so that
          # warnings from the type checker are reported too.
          assert {:ok, [^module], warnings} =
                   Kernel.ParallelCompiler.compile([source], return_diagnostics: true)

          assert warnings == %{compile_warnings: [], runtime_warnings: []},
                 "compiling the #{shape} catalog warned: #{inspect(warnings)}"

          {shape, module}
        end

      backend = backends.static_only
      assert backend.lgettext("it", "default", nil, "Hello world", %{}) == {:ok, "Ciao mondo"}

      # An empty context is not the same as no context, as with function clauses.
      assert backend.lgettext("it", "default", "", "Empty context", %{}) ==
               {:ok, "Contesto vuoto"}

      assert backend.lgettext("it", "default", nil, "Empty context", %{}) ==
               {:default, "Empty context"}

      assert backend.lgettext("it", "default", "greeting", "Hello world", %{}) ==
               {:ok, "Ciao mondo (saluto)"}

      assert backend.lgettext("it", "default", "other", "Hello world", %{}) ==
               {:default, "Hello world"}

      assert backend.lgettext("it", "default", nil, "Gone", %{}) == {:default, "Gone"}

      backend = backends.interpolated_only

      assert backend.lgettext("it", "default", nil, "Hello %{name}", %{name: "Jane"}) ==
               {:ok, "Ciao Jane"}

      assert backend.lgettext("it", "default", nil, "Hello world", %{}) ==
               {:default, "Hello world"}

      backend = backends.plural_only

      assert backend.lgettext("it", "default", nil, "One new email", %{}) ==
               {:ok, "Una nuova email"}

      assert backend.lgettext("it", "default", nil, "Hello world", %{}) ==
               {:default, "Hello world"}
    end
  end

  describe "__gettext__/1 (generated)" do
    test "with :priv returns the directory where messages are stored" do
      assert Backend.__gettext__(:priv) == "test/fixtures/single_messages"
    end

    test "with :otp_app returns the OTP app for the given backend" do
      assert Backend.__gettext__(:otp_app) == :test_application
    end

    test "with :default_domain returns the default domain for the given backend" do
      assert Backend.__gettext__(:default_domain) == "default"
      assert BackendWithDefaultDomain.__gettext__(:default_domain) == "errors"
    end
  end

  describe "c:lgettext/5" do
    test "returns {:ok, translation} for found translations" do
      assert Backend.lgettext("it", "default", nil, "Hello world", %{}) == {:ok, "Ciao mondo"}

      assert Backend.lgettext("it", "errors", nil, "Invalid email address", %{}) ==
               {:ok, "Indirizzo email non valido"}
    end

    test "returns {:default, msgid} for missing translations" do
      # Unknown msgid.
      assert Backend.lgettext("it", "default", nil, "nonexistent", %{}) ==
               {:default, "nonexistent"}

      # Unknown domain.
      assert Backend.lgettext("it", "unknown", nil, "Hello world", %{}) ==
               {:default, "Hello world"}

      # Unknown locale.
      assert Backend.lgettext("pt_BR", "nonexistent", nil, "Hello world", %{}) ==
               {:default, "Hello world"}
    end

    test "returns {:ok, translation} for translations with a context" do
      assert Backend.lgettext("it", "default", "test", "Hello world", %{}) == {:ok, "Ciao mondo"}

      assert Backend.lgettext("it", "default", "test", "Hello %{name}", %{name: "Jane"}) ==
               {:ok, "Ciao Jane"}

      assert Backend.lgettext("it", "default", "other", "Hello world", %{}) ==
               {:default, "Hello world"}
    end

    test "returns translations with literal braces as they are" do
      assert Backend.lgettext("it", "default", nil, "Literal braces", %{}) ==
               {:ok, "Parentesi %{} letterali"}

      assert Backend.lgettext("it", "default", nil, "Literal braces", %{name: "Jane"}) ==
               {:ok, "Parentesi %{} letterali"}
    end

    test "returns {:default, msgid} if the msgstr is an empty string" do
      assert Backend.lgettext("it", "default", nil, "Empty msgstr!", %{}) ==
               {:default, "Empty msgstr!"}
    end

    test "supports translating the msgid of plural translations" do
      assert Backend.lgettext("it", "errors", nil, "There was an error", %{}) ==
               {:ok, "C'è stato un errore"}
    end

    test "supports interpolation with found translations" do
      assert Backend.lgettext("it", "interpolations", nil, "Hello %{name}", %{name: "Jane"}) ==
               {:ok, "Ciao Jane"}

      msgid = "My name is %{name} and I'm %{age}"

      assert Backend.lgettext("it", "interpolations", nil, msgid, %{name: "Meg", age: 33}) ==
               {:ok, "Mi chiamo Meg e ho 33 anni"}

      # A map of bindings is supported as well.
      assert Backend.lgettext("it", "interpolations", nil, "Hello %{name}", %{name: "Jane"}) ==
               {:ok, "Ciao Jane"}
    end

    test "supports interpolation with missing translations" do
      msgid = "Hello %{name}, missing message!"

      assert Backend.lgettext("pl", "foo", nil, msgid, %{name: "Samantha"}) ==
               {:default, "Hello Samantha, missing message!"}

      msgid = "Hello world!"
      assert Backend.lgettext("pl", "foo", nil, msgid, %{}) == {:default, "Hello world!"}

      msgid = "Hello %{name}"

      assert Backend.lgettext("pl", "foo", nil, msgid, %{}) ==
               {:missing_bindings, "Hello %{name}", [:name]}
    end

    test "falls back to handle_missing_translation" do
      msgctxt = "some context"
      msgid = "Hello %{name}"
      bindings = %{name: "Jane"}

      assert Backend.lgettext("pl", "foo", msgctxt, msgid, bindings) ==
               {:default, "Hello Jane"}

      assert_receive {"pl", "foo", ^msgctxt, ^msgid, ^bindings}
    end

    test "preserves the key when using the default c:handle_missing_bindings/2" do
      msgid = "My name is %{name} and I'm %{age}"

      assert Backend.lgettext("it", "interpolations", nil, msgid, %{name: "José"}) ==
               {:missing_bindings, "Mi chiamo José e ho %{age} anni", [:age]}
    end

    test "strings are concatenated before generating function clauses" do
      msgid = "Concatenated and long string"

      assert Backend.lgettext("it", "default", msgid, %{}) ==
               {:ok, "Stringa lunga e concatenata"}

      assert Backend.lgettext("it", "default", nil, msgid, %{}) ==
               {:ok, "Stringa lunga e concatenata"}

      msgid = "A friend"
      msgid_plural = "%{count} friends"

      assert Backend.lngettext("it", "default", nil, msgid, msgid_plural, 1, %{}) ==
               {:ok, "Un amico"}
    end

    test "warns if the domain contains slashes" do
      log =
        capture_log(fn ->
          assert Backend.lgettext("it", "sub/dir/domain", nil, "hello", %{}) ==
                   {:default, "hello"}
        end)

      assert log =~ ~s(Slashes in domains are not supported: "sub/dir/domain")
    end

    test "with :allowed_locales ignores other locales as strings" do
      assert GettextTest.BackendWithAllowedLocalesString.lgettext(
               "it",
               "default",
               nil,
               "Hello world",
               %{}
             ) ==
               {:default, "Hello world"}

      assert GettextTest.BackendWithAllowedLocalesString.lgettext(
               "es",
               "default",
               nil,
               "Hello world",
               %{}
             ) ==
               {:ok, "Hola mundo"}
    end

    test "with :allowed_locales ignores other locales as atom" do
      assert GettextTest.BackendWithAllowedLocalesAtom.lgettext(
               "it",
               "default",
               nil,
               "Hello world",
               %{}
             ) ==
               {:default, "Hello world"}

      assert GettextTest.BackendWithAllowedLocalesAtom.lgettext(
               "es",
               "default",
               nil,
               "Hello world",
               %{}
             ) ==
               {:ok, "Hola mundo"}
    end
  end

  describe "c:lngettext/7" do
    test "returns {:ok, translation} for found translations" do
      message =
        Backend.lngettext(
          "it",
          "errors",
          nil,
          "There was an error",
          "There were %{count} errors",
          1,
          %{}
        )

      assert message == {:ok, "C'è stato un errore"}

      message =
        Backend.lngettext(
          "it",
          "errors",
          nil,
          "There was an error",
          "There were %{count} errors",
          3,
          %{}
        )

      assert message == {:ok, "Ci sono stati 3 errori"}

      assert {:ok, "3 エラーがありました"} =
               Backend.lngettext(
                 "ja",
                 "errors",
                 nil,
                 "There was an error",
                 "There were %{count} errors",
                 3,
                 %{}
               )
    end

    test "returns {:default, msgid(_plural)} for missing translations" do
      assert Backend.lngettext("it", "not a domain", nil, "foo", "foos", 1, %{}) ==
               {:default, "foo"}

      assert Backend.lngettext("it", "not a domain", nil, "foo", "foos", 10, %{}) ==
               {:default, "foos"}
    end

    test "returns {:default, msgid(_plural)} for translations with empty msgstr" do
      msgid = "Not even one msgstr"
      msgid_plural = "Not even %{count} msgstrs"

      assert Backend.lngettext("it", "default", nil, msgid, msgid_plural, 1, %{}) ==
               {:default, "Not even one msgstr"}

      assert Backend.lngettext("it", "default", nil, msgid, msgid_plural, 2, %{}) ==
               {:default, "Not even 2 msgstrs"}
    end

    test "supports interpolation" do
      msgid = "There was an error"
      msgid_plural = "There were %{count} errors"

      assert Backend.lngettext("it", "errors", nil, msgid, msgid_plural, 1, %{}) ==
               {:ok, "C'è stato un errore"}

      assert Backend.lngettext("it", "errors", nil, msgid, msgid_plural, 4, %{}) ==
               {:ok, "Ci sono stati 4 errori"}

      msgid = "You have one message, %{name}"
      msgid_plural = "You have %{count} messages, %{name}"

      assert Backend.lngettext("it", "interpolations", nil, msgid, msgid_plural, 1, %{
               name: "Jane"
             }) ==
               {:ok, "Hai un messaggio, Jane"}

      assert Backend.lngettext("it", "interpolations", nil, msgid, msgid_plural, 0, %{
               name: "Jane"
             }) ==
               {:ok, "Hai 0 messaggi, Jane"}
    end

    test "supports interpolation with missing translations" do
      msgid = "One error"
      msgid_plural = "%{count} errors"

      assert Backend.lngettext("pl", "foo", nil, msgid, msgid_plural, 1, %{}) ==
               {:default, "One error"}

      assert Backend.lngettext("pl", "foo", nil, msgid, msgid_plural, 9, %{}) ==
               {:default, "9 errors"}
    end

    test "falls back to c:handle_missing_binding/2" do
      msgid = "You have one message, %{name}"
      msgid_plural = "You have %{count} messages, %{name}"

      assert Backend.lngettext("it", "interpolations", nil, msgid, msgid_plural, 1, %{}) ==
               {:missing_bindings, "Hai un messaggio, %{name}", [:name]}

      assert Backend.lngettext("it", "interpolations", nil, msgid, msgid_plural, 6, %{}) ==
               {:missing_bindings, "Hai 6 messaggi, %{name}", [:name]}
    end

    test "uses the default c:handle_missing_plural_translation/7 implementation" do
      msgctxt = "some context"
      msgid = "Hello %{name}"
      msgid_plural = "Hello %{name}"
      bindings = %{name: "Jane"}

      assert Backend.lngettext(
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

    test "warns if the domain contains slashes" do
      log =
        capture_log(fn ->
          assert Backend.lngettext("it", "sub/dir/domain", nil, "hello", "hellos", 2, %{}) ==
                   {:default, "hellos"}
        end)

      assert log =~ ~s(Slashes in domains are not supported: "sub/dir/domain")
    end

    test "supports a custom Gettext.Plural module" do
      assert BackendWithCustomPluralForms.lngettext(
               "it",
               "default",
               nil,
               "One new email",
               "%{count} new emails",
               1,
               %{}
             ) ==
               {:ok, "1 nuove email"}

      assert BackendWithCustomPluralForms.lngettext(
               "it",
               "default",
               nil,
               "One new email",
               "%{count} new emails",
               2,
               %{}
             ) ==
               {:ok, "Una nuova email"}
    end

    test "supports a custom Gettext.Plural module with the context parameter" do
      alias BackendWithCustomCompiledPluralForms, as: T

      assert T.lngettext("it", "default", nil, "One new email", "%{count} new emails", 1, %{})

      assert_received {:plural_context, %{plural_forms_header: "nplurals=2; plural=(n != 1);"}}
    end

    test "supports a custom Gettext.Plural module from app environment" do
      Application.put_env(:gettext, :plural_forms, GettextTest.CustomPlural)

      defmodule BackendWithAppPluralForms do
        use Gettext.Backend, otp_app: :test_application, priv: "test/fixtures/single_messages"
      end

      assert BackendWithAppPluralForms.lngettext(
               "it",
               "default",
               nil,
               "One new email",
               "%{count} new emails",
               1,
               %{}
             ) ==
               {:ok, "1 nuove email"}

      assert BackendWithAppPluralForms.lngettext(
               "it",
               "default",
               nil,
               "One new email",
               "%{count} new emails",
               2,
               %{}
             ) ==
               {:ok, "Una nuova email"}
    after
      Application.put_env(:gettext, :plural_forms, Gettext.Plural)
    end

    test "raises an error if a plural message has no plural form for the given locale" do
      log =
        capture_log(fn ->
          Code.eval_quoted(
            quote do
              defmodule BadTranslations do
                use Gettext.Backend,
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
                     apply(BadTranslations, :lngettext, [
                       "ru",
                       "errors",
                       nil,
                       msgid,
                       msgid_plural,
                       8,
                       %{}
                     ])
                   end
    end
  end
end
