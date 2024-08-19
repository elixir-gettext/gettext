defmodule GettextTest.CustomPlural do
  @behaviour Gettext.Plural
  def nplurals("elv"), do: 2
  def nplurals(other), do: Gettext.Plural.nplurals(other)
  # Opposite of Italian (where 1 is singular, everything else is plural)
  def plural("it", 1), do: 1
  def plural("it", _), do: 0
end

defmodule GettextTest.CustomCompiledPlural do
  @behaviour Gettext.Plural

  @impl Gettext.Plural
  def init(plural_info), do: plural_info

  @impl Gettext.Plural
  def nplurals(plural_info) do
    send(self(), {:nplurals_context, plural_info})

    plural_info
    |> Gettext.Plural.init()
    |> Gettext.Plural.nplurals()
  end

  @impl Gettext.Plural
  def plural(plural_info, count) do
    send(self(), {:plural_context, plural_info})

    plural_info
    |> Gettext.Plural.init()
    |> Gettext.Plural.plural(count)
  end
end

defmodule GettextTest.Backend do
  use Gettext.Backend,
    otp_app: :test_application,
    priv: "test/fixtures/single_messages"

  def handle_missing_translation(locale, domain, msgctxt, msgid, bindings) do
    send(self(), {locale, domain, msgctxt, msgid, bindings})
    super(locale, domain, msgctxt, msgid, bindings)
  end

  def handle_missing_plural_translation(
        locale,
        domain,
        msgctxt,
        msgid,
        msgid_plural,
        n,
        bindings
      ) do
    send(self(), {locale, domain, msgctxt, msgid, msgid_plural, n, bindings})
    super(locale, domain, msgctxt, msgid, msgid_plural, n, bindings)
  end
end

defmodule GettextTest.BackendWithAllowedLocalesString do
  use Gettext.Backend,
    otp_app: :test_application,
    priv: "test/fixtures/multi_messages",
    allowed_locales: ["es"]
end

defmodule GettextTest.BackendWithAllowedLocalesAtom do
  use Gettext.Backend,
    otp_app: :test_application,
    priv: "test/fixtures/multi_messages",
    allowed_locales: [:es]
end

defmodule GettextTest.BackendWithDefaultDomain do
  use Gettext.Backend,
    otp_app: :test_application,
    priv: "test/fixtures/single_messages",
    default_domain: "errors"
end

ExUnit.start()
