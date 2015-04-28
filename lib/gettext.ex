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

  defmodule Error do
    defexception [:message]

    def exception(message) do
      %__MODULE__{message: message}
    end
  end

  @type locale :: binary

  @doc false
  defmacro __using__(opts) do
    quote do
      @gettext_opts unquote(opts)
      @before_compile Gettext.Compiler
      unquote(Gettext.Compiler.signatures)
    end
  end

  @doc """
  Gets the locale for the current process.

  This function returns the value of the locale for the current process. If
  there is no locale for the current process, the default locale is set as the
  locale for the current process and then returned. For more information on the
  default locale, refer to the documentation of the `Gettext` module.

  ## Examples

      Gettext.locale()
      #=> "en"

  """
  @spec locale() :: locale
  def locale do
    if locale = Process.get(__MODULE__) do
      locale
    else
      default_locale = Application.get_env(:gettext, :default_locale)
      Process.put(__MODULE__, default_locale)
      default_locale
    end
  end

  @doc """
  Sets the locale for the current process.

  `locale` must be a string; if it's not, an `ArgumentError` exception is
  raised.

  ## Examples

      Gettext.locale("pt_BR")
      #=> nil
      Gettext.locale
      #=> "pt_BR"

  """
  @spec locale(locale) :: nil
  def locale(locale) when is_binary(locale),
    do: Process.put(__MODULE__, locale)
  def locale(_locale),
    do: raise(ArgumentError, "locale/1 only accepts binary locales")

  @spec dgettext(atom, binary, binary, Map.t) :: binary
  def dgettext(backend, domain, string, bindings \\ %{})

  def dgettext(backend, domain, string, bindings) when is_list(bindings) do
    dgettext(backend, domain, string, Enum.into(bindings, %{}))
  end

  def dgettext(backend, domain, string, bindings) do
    backend.lgettext(locale(), domain, string, bindings)
    |> handle_backend_result
  end

  @spec gettext(atom, binary, Map.t) :: binary
  def gettext(backend, string, bindings \\ %{}) do
    dgettext(backend, "default", string, bindings)
  end

  @spec dngettext(atom, binary, binary, binary, non_neg_integer, Map.t) :: binary
  def dngettext(backend, domain, id, plural_id, n, bindings \\ %{})

  def dngettext(backend, domain, id, plural_id, n, bindings) when is_list(bindings) do
    dngettext(backend, domain, id, plural_id, n, Enum.into(bindings, %{}))
  end

  def dngettext(backend, domain, id, plural_id, n, bindings) do
    backend.lngettext(locale(), domain, id, plural_id, n, bindings)
    |> handle_backend_result
  end

  @spec ngettext(atom, binary, binary, non_neg_integer, Map.t) :: binary
  def ngettext(backend, id, plural_id, n, bindings \\ %{}) do
    dngettext(backend, "default", id, plural_id, n, bindings)
  end

  defp handle_backend_result({atom, string}) when atom in [:ok, :default],
    do: string
  defp handle_backend_result({:error, error}),
    do: raise(Error, error)
end
