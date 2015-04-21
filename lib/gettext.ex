defmodule Gettext do
  @moduledoc """
  Provides facilities generating translation functions based on `.po` files.

  In order to use the functionality provided by gettext in a module, the
  `Gettext` module must be used in that module.

  ## Options

  The following is a list of options that can be passed when `Gettext` is used:

    * `:otp_app` - the OTP application that contains the translation files
      (the files with the `.po` extension).
    * `:priv` - the directory where the translations are located. Defaults to
      `priv/gettext`.

  ## Examples

  Let's say that the file at `priv/gettext/pt_BR/LC_MESSAGES/default.po` in the
  `:my_app` OTP application contains the following:

      msgid "Hello world"
      msgstr "Ola mundo"

  Then `Gettext` can be used like this:

      defmodule MyApp.Gettext do
        use Gettext, otp_app: :my_app
      end

  and the `MyApp.Gettext.lgettext/3` function will be made available:

      MyApp.Gettext.lgettext("pt_BR", "default", "Hello world")
      #=> {:ok, "Ola mundo"}

  This function will default to "mirroring" the argument message if no
  translation is found:

      MyApp.Gettext.lgettext("it_IT", "default", "Hello world")
      #=> {:default, "Hello world"}

  """

  @type locale :: binary

  @default_locale "en"

  @doc false
  defmacro __using__(opts) do
    quote do
      @gettext_opts unquote(opts)
      @before_compile Gettext.Compiler
      unquote(Gettext.Compiler.signatures)
    end
  end

  @spec locale() :: locale
  def locale do
    if locale = Process.get(__MODULE__) do
      locale
    else
      default_locale = Application.get_env(:gettext, :default_locale, @default_locale)
      Process.put(__MODULE__, default_locale)
      default_locale
    end
  end

  @spec locale(locale) :: nil
  def locale(locale) when is_binary(locale),
    do: Process.put(__MODULE__, locale)
  def locale(_locale),
    do: raise(ArgumentError, "locale/1 only accepts binary locales")

  @spec dgettext(atom, binary, binary, Map.t) :: binary
  def dgettext(backend, domain, string, bindings \\ %{}) do
    case backend.lgettext(locale(), domain, string, bindings) do
      {:ok, string} ->
        string
      {:default, string} ->
        string
      {:error, error} ->
        raise Gettext.Interpolation.MissingKeysError, error
    end
  end

  @spec gettext(atom, binary, Map.t) :: binary
  def gettext(backend, string, bindings \\ %{}) do
    dgettext(backend, "default", string, bindings)
  end
end
