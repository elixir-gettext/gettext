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

      # Catchall clauses.
      def lgettext(_, _, msg),
        do: {:default, msg}

      def lngettext(_, _, msgid, _msgid_plural, _n),
        do: {:default, msgid}
    end
  end

  @doc false
  # TODO Support decent interpolation, possibly at compile time. This is only a
  # temporary (hackish) solution.
  def pluralize(locale, msgstr, n) do
    plural_form = Gettext.Plural.plural(locale, n)
    translation = Map.get(msgstr, plural_form)
    {:ok, replace_count(translation, n)}
  end

  defp replace_count(string, n) do
    String.replace string, "%{count}", to_string(n)
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

  # Compiles a pluralized translation into a function clause like:
  #
  #     def lngettext(locale, domain, msgid, msgid_plural, n)
  #
  defp compile_translation(locale, domain, %Translation{msgid: msgid, msgid_plural: msgid_plural, msgstr: msgstr})
      when not is_nil(msgid_plural) do
    quote do
      def lngettext(unquote(locale), unquote(domain), unquote(msgid), unquote(msgid_plural), n) do
        Gettext.pluralize(unquote(locale), unquote(Macro.escape(msgstr)), n)
      end
    end
  end

  # Compiles a translation into a function clause like:
  #
  #     def lgettext(locale, domain, msgid)
  #
  defp compile_translation(locale, domain, %Translation{msgid: msgid, msgstr: msgstr}) do
    quote do
      def lgettext(unquote(locale), unquote(domain), unquote(msgid)) do
        {:ok, unquote(msgstr)}
      end
    end
  end
end
