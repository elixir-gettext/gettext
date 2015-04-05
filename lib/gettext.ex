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

  alias Gettext.PO.Translation

  @default_priv "priv/gettext"

  @doc false
  defmacro __using__(opts) do
    quote do
      @gettext_opts unquote(opts)
      @before_compile Gettext
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    opts             = Module.get_attribute(env.module, :gettext_opts)
    otp_app          = Keyword.fetch!(opts, :otp_app)
    priv             = Keyword.get(opts, :priv, @default_priv)
    translations_dir = Application.app_dir(otp_app, priv)

    quote do
      unquote(compile_po_files(translations_dir))

      # Catchall clause.
      def lgettext(_, _, msg) do
        {:default, msg}
      end
    end
  end

  defp compile_po_files(dir) do
    # `true` means recursively. The last argument is the initial accumulator.
    :filelib.fold_files(dir, "\.po$", true, &compile_po_file/2, [])
  end

  defp compile_po_file(path, acc) do
    {locale, domain} = locale_and_domain_from_path(path)
    translations     = Gettext.PO.parse_file!(path)

    Enum.reduce translations, acc, fn
      translation, acc -> [compile_translation(locale, domain, translation)|acc]
    end
  end

  defp locale_and_domain_from_path(path) do
    [file, "LC_MESSAGES", locale|_rest] = path |> Path.split |> Enum.reverse
    domain = Path.rootname(file, ".po")
    {locale, domain}
  end

  # Compiles a single translation into a function clause in the form:
  #
  #   def lgettext("it_IT", "default", "Hello world"), do: {:ok, "Ciao mondo"}
  #
  defp compile_translation(locale, domain, %Translation{msgid: msgid, msgstr: msgstr}) do
    quote do
      def lgettext(unquote(locale), unquote(domain), unquote(msgid)) do
        {:ok, unquote(msgstr)}
      end
    end
  end
end
