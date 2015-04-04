defmodule Gettext do
  alias Gettext.PO.Translation

  @default_priv "priv/gettext"

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts, default_priv: @default_priv] do
      otp_app          = Keyword.fetch!(opts, :otp_app)
      priv             = Keyword.get(opts, :priv, default_priv)
      translations_dir = Application.app_dir(otp_app, priv)

      Module.eval_quoted __MODULE__, Gettext.compile_po_files(translations_dir)

      # Catchall clause.
      def lgettext(_, _, msg) do
        {:default, msg}
      end
    end
  end

  # Made public so that it can be called inside the quoted contents of the
  # `__using__` macro.
  @doc false
  def compile_po_files(dir) do
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
