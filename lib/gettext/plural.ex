defmodule Gettext.Plural do
  @moduledoc """
  Behaviour and default implementation for finding plural forms in given
  locales.

  This module both defines the `Gettext.Plural` behaviour and provides a default
  implementation for it.

  ## Plural forms

  > For a given language, there is a grammatical rule on how to change words
  > depending on the number qualifying the word. Different languages can have
  > different rules.
  [[source]](https://udn.realityripple.com/docs/Mozilla/Localization/Localization_and_Plurals)

  Such grammatical rules define a number of **plural forms**. For example,
  English has two plural forms: one for when there is just one element (the
  *singular*) and another one for when there are zero or more than one elements
  (the *plural*). There are languages which only have one plural form and there
  are languages which have more than two.

  In GNU Gettext (and in Gettext for Elixir), plural forms are represented by
  increasing 0-indexed integers. For example, in English `0` means singular and
  `1` means plural.

  The goal of this module is to determine, given a locale:

    * how many plural forms exist in that locale (`nplurals/1`);
    * to what plural form a given number of elements belongs to in that locale
      (`plural/2`).

  ## Default implementation

  `Gettext.Plural` provides a default implementation of a plural module. Most
  languages used on Earth should be covered by this default implementation. If
  custom pluralization rules are needed (for example, to add additional
  languages) a different plural module can be specified when creating a Gettext
  backend. For example, pluralization rules for the Elvish language could be
  added as follows:

      defmodule MyApp.Plural do
        @behaviour Gettext.Plural

        def nplurals("elv"), do: 3

        def plural("elv", 0), do: 0
        def plural("elv", 1), do: 1
        def plural("elv", _), do: 2

        # Fallback to Gettext.Plural
        def nplurals(locale), do: Gettext.Plural.nplurals(locale)
        def plural(locale, n), do: Gettext.Plural.plural(locale, n)
      end

  The mathematical expressions used in this module to determine the plural form
  of a given number of elements are taken from [this
  page](http://localization-guide.readthedocs.org/en/latest/l10n/pluralforms.html#f2)
  as well as from [Mozilla's guide on "Localization and
  plurals"](https://udn.realityripple.com/docs/Mozilla/Localization/Localization_and_Plurals).

  Now that we have defined our custom plural forms, we can use them
  in two ways. You can set it for all `:gettext` backends in your
  config files:

      config :gettext, :plural_forms, MyApp.Plural

  Or to each specific backend:

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app, plural_forms: MyApp.Plural
      end

  **Note**: set `:plural_forms` in your `config/config.exs` and
  not in `config/runtime.exs`, as this configuration is read when
  compiling your backends.

  Notice that tasks such as `mix gettext.merge` use the plural
  backend configured under the `:gettext` application, so generally
  speaking the first format is preferred.

  Note some tasks also allow the number of plural forms to be given
  explicitly, for example:

      mix gettext.merge priv/gettext --locale=gsw_CH --plural-forms=2

  ### Unknown locales

  Trying to call `Gettext.Plural` functions with unknown locales will result in
  a `Gettext.Plural.UnknownLocaleError` exception.

  ### Language and territory

  Often, a locale is composed as a language and territory couple, such as
  `en_US`. The default implementation for `Gettext.Plural` handles `xx_YY` by
  forwarding it to `xx` (except for *just Brazilian Portuguese*, `pt_BR`, which
  is not forwarded to `pt` as pluralization rules slightly differ). We treat the
  underscore as a separator according to
  [ISO 15897](https://en.wikipedia.org/wiki/ISO/IEC_15897). Sometimes, a dash `-` is
  used as a separator (for example [BCP47](https://en.wikipedia.org/wiki/IETF_language_tag)
  locales use this as in `en-US`): this is not forwarded to `en` in the default
  `Gettext.Plural` (and it will raise an `Gettext.Plural.UnknownLocaleError` exception
  if there are no translations for `en-US`).

  ## Examples

  An example of the plural form of a given number of elements in the Polish
  language:

      iex> Plural.plural("pl", 1)
      0
      iex> Plural.plural("pl", 2)
      1
      iex> Plural.plural("pl", 5)
      2
      iex> Plural.plural("pl", 112)
      2

  As expected, `nplurals/1` returns the possible number of plural forms:

      iex> Plural.nplurals("pl")
      3

  """

  # Behaviour definition.

  @doc """
  Returns the number of possible plural forms in the given `locale`.
  """
  @callback nplurals(locale :: String.t()) :: pos_integer

  @doc """
  Returns the plural form in the given `locale` for the given `count` of
  elements.
  """
  @callback plural(locale :: String.t(), count :: integer) :: plural_form :: non_neg_integer

  defmodule UnknownLocaleError do
    @moduledoc """
    Raised when a pluralized module doesn't know how to handle a locale.

    ## Examples

        raise Gettext.Plural.UnknownLocaleError, "en-US"

    """

    defexception [:message]

    def exception(locale) when is_binary(locale) do
      message = """
      unknown locale #{inspect(locale)}. If this is a locale you need to handle,
      consider using a custom pluralizer module instead of the default
      Gettext.Plural. You can read more about this on the Gettext docs at
      https://hexdocs.pm/gettext/Gettext.Plural.html
      """

      %__MODULE__{message: message}
    end
  end

  # Number of plural forms.

  @spec nplurals(locale :: String.t()) :: pos_integer()
  def nplurals(locale)

  for locale <- Expo.PluralForms.known_locales() do
    {:ok, {nplurals, _plural_forms}} = Expo.PluralForms.plural_form(locale)
    def nplurals(unquote(locale)), do: unquote(nplurals)
  end

  # Match-all clause.
  def nplurals(locale) do
    recall_if_territory_or_raise(locale, &nplurals/1)
  end

  # Plural form of groupable languages.

  @spec plural(locale :: String.t(), count :: integer()) :: non_neg_integer()
  def plural(locale, count)

  for locale <- Expo.PluralForms.known_locales() do
    {:ok, {_nplurals, plural_forms}} = Expo.PluralForms.plural_form(locale)

    def plural(unquote(locale), n),
      do:
        unquote({:__block__, [],
         [
           # Ignore n variable
           {:=, [],
            [{:_, [], Elixir}, {:var!, [context: Elixir, import: Kernel], [{:n, [], Elixir}]}]},
           Expo.PluralForms.compile_index(plural_forms)
         ]})
  end

  # Match-all clause.
  def plural(locale, n) do
    recall_if_territory_or_raise(locale, &plural(&1, n))
  end

  defp recall_if_territory_or_raise(locale, fun) do
    case String.split(locale, "_", parts: 2, trim: true) do
      [lang, _territory] -> fun.(lang)
      _other -> raise UnknownLocaleError, locale
    end
  end
end
