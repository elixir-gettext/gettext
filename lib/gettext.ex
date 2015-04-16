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
  alias Gettext.PO.PluralTranslation
  alias Gettext.Interpolation

  @default_priv "priv/gettext"
  @pluralizer Application.get_env(:gettext, :plural_forms, Gettext.Plural)

  @doc false
  defmacro __using__(opts) do
    quote do
      @gettext_opts unquote(opts)
      @before_compile Gettext

      def lgettext(locale, domain, msgid, bindings \\ %{})
      def lngettext(locale, domain, msgid, msgid_plural, n, bindings \\ %{})
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
      def lgettext(_, _, default, bindings) do
        case Gettext.Interpolation.interpolate(default, bindings) do
          {:ok, interpolated} -> {:default, interpolated}
          {:error, _} = error -> error
        end
      end

      def lngettext(_, _, msgid, msgid_plural, n, bindings) do
        str = if n == 1, do: msgid, else: msgid_plural
        bindings = Map.put(bindings, :count, n)

        case Gettext.Interpolation.interpolate(str, bindings) do
          {:ok, interpolated} -> {:default, interpolated}
          {:error, _} = error -> error
        end
      end
    end
  end

  defp compile_po_files(dir) do
    # `true` means recursively. The last argument is the initial accumulator.
    :filelib.fold_files(dir, "\.po$", true, &compile_po_file(&1, &2), [])
  end

  # `acc` is a list of already compiled translation, i.e., of quoted function
  # definitions.
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

  defp compile_translation(locale, domain, %Translation{} = t) do
    bindings_match        = compile_bindings_match(t.msgstr)
    interpolated_bindings = compile_interpolated_bindings(t.msgstr)
    required_keys         = Interpolation.bindings_in_string(t.msgstr)

    quote do
      def lgettext(unquote(locale), unquote(domain), unquote(t.msgid), bindings) do
        if is_list(bindings) do
          bindings = Enum.into(bindings, %{})
        end

        case bindings do
          unquote(bindings_match) ->
            {:ok, unquote(interpolated_bindings)}
          _ ->
            {:error, Gettext.Interpolation.missing_interpolation_keys(bindings, unquote(required_keys))}
        end
      end
    end
  end

  defp compile_translation(locale, domain, %PluralTranslation{} = t) do
    forms = for {form, str} <- t.msgstr, into: %{} do
      match    = compile_bindings_match(str)
      interp   = compile_interpolated_bindings(str)
      required = Interpolation.bindings_in_string(str)

      quoted = quote do
        case var!(bindings) do
          unquote(match) ->
            {:ok, unquote(interp)}
          _ ->
            {:error, Gettext.Interpolation.missing_interpolation_keys(var!(bindings), unquote(required))}
        end
      end

      {form, quoted}
    end

    quote do
      def lngettext(unquote(locale), unquote(domain), unquote(t.msgid), unquote(t.msgid_plural), n, bindings) do
        if is_list(bindings) do
          bindings = Enum.into bindings, %{}
        end
        form = unquote(@pluralizer).plural(unquote(locale), n)
        bindings = Map.put(bindings, :count, n)
        q = Map.fetch!(unquote(Macro.escape(forms)), form)
        {res, _} = Code.eval_quoted(q, bindings: bindings)
        res
      end
    end
  end

  defp compile_bindings_match(str) do
    kv = for binding <- Interpolation.bindings_in_string(str) do
      {binding, Macro.var(binding, __MODULE__)}
    end

    {:%{}, [], kv}
  end

  # Heavily inspired by Chris McCord's "linguist", see
  # https://github.com/chrismccord/linguist/blob/master/lib/linguist/compiler.ex#L70
  defp compile_interpolated_bindings(str) do
    Enum.reduce Interpolation.to_interpolatable(str), "", fn
      key, acc when is_atom(key) ->
        quote do
          unquote(acc) <> to_string(unquote(Macro.var(key, __MODULE__)))
        end
      str, acc ->
        quote do
          unquote(acc) <> unquote(str)
        end
    end
  end
end
