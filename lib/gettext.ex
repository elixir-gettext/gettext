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
  @plural_forms Application.get_env(:gettext, :plural_forms, Gettext.Plural)

  @doc false
  defmacro __using__(opts) do
    quote do
      @gettext_opts unquote(opts)
      @before_compile Gettext

      def lgettext(locale, domain, msgid, bindings \\ %{})

      def lgettext(locale, domain, msgid, bindings) when is_list(bindings) do
        lgettext(locale, domain, msgid, Enum.into(bindings, %{}))
      end

      def lngettext(locale, domain, msgid, msgid_plural, n, bindings \\ %{})

      def lngettext(locale, domain, msgid, msgid_plural, n, bindings) when is_list(bindings) do
        lngettext(locale, domain, msgid, msgid_plural, n, Enum.into(bindings, %{}))
      end
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
        str      = if n == 1, do: msgid, else: msgid_plural
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
    quote do
      def lgettext(unquote(locale), unquote(domain), unquote(t.msgid), var!(bindings)) do
        unquote(compile_interpolation_code(t.msgstr))
      end
    end
  end

  defp compile_translation(locale, domain, %PluralTranslation{} = t) do
    clauses = Enum.map t.msgstr, fn({form, str}) ->
      {:->, [], [[form], compile_interpolation_code(str)]}
    end

    quote do
      def lngettext(unquote(locale), unquote(domain), unquote(t.msgid), unquote(t.msgid_plural), n, bindings) do
        plural_form    = unquote(@plural_forms).plural(unquote(locale), n)
        var!(bindings) = Map.put(bindings, :count, n)

        case plural_form, do: unquote(clauses)
      end
    end
  end

  # Compiles a string into a full-blown `case` statement which interpolates the
  # string based on some bindings or returns an error in case those bindings are
  # missing. Note that the `bindings` variable is assumed to be in the scope by
  # the quoted code that is returned.
  defp compile_interpolation_code(str) do
    keys          = Interpolation.keys(str)
    match         = compile_interpolation_match(keys)
    interpolation = compile_interpolation(str)

    quote do
      case var!(bindings) do
        unquote(match) ->
          {:ok, unquote(interpolation)}
        _ ->
          keys = unquote(keys)
          {:error, Gettext.Interpolation.missing_interpolation_keys(var!(bindings), keys)}
      end
    end
  end

  # Compiles a list of atoms into a "match" map. For example `[:foo, :bar]` gets
  # compiled to `%{foo: foo, bar: bar}`. All generated variables are under the
  # current `__MODULE__`.
  defp compile_interpolation_match(keys) do
    {:%{}, [], Enum.map(keys, &{&1, Macro.var(&1, __MODULE__)})}
  end

  # Compiles a string into a sequence of applications of the `<>` operator.
  # `%{var}` patterns are turned into `var` variables, namespaced inside the
  # current `__MODULE__`. Heavily inspired by Chris McCord's "linguist", see
  # https://github.com/chrismccord/linguist/blob/master/lib/linguist/compiler.ex#L70
  defp compile_interpolation(str) do
    Enum.reduce Interpolation.to_interpolatable(str), "", fn
      key, acc when is_atom(key) ->
        quote do: unquote(acc) <> to_string(unquote(Macro.var(key, __MODULE__)))
      str, acc ->
        quote do: unquote(acc) <> unquote(str)
    end
  end
end
