defmodule Gettext.Compiler do
  @moduledoc false

  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation
  alias Gettext.Interpolation

  @default_priv "priv/gettext"
  @po_wildcard "*/LC_MESSAGES/*.po"

  @doc false
  defmacro __before_compile__(env) do
    opts             = Module.get_attribute(env.module, :gettext_opts)
    otp_app          = Keyword.fetch!(opts, :otp_app)
    priv             = Keyword.get(opts, :priv, @default_priv)
    external_file    = Path.join(".compile", priv) |> String.replace("/", "_")
    translations_dir = Application.app_dir(otp_app, priv)
    known_locales    = known_locales(translations_dir)
    plural_forms     = Keyword.get(opts, :plural_forms, Gettext.Plural)

    quote do
      @behaviour Gettext.Backend

      @doc false
      def __gettext__(:priv),          do: unquote(priv)
      def __gettext__(:otp_app),       do: unquote(otp_app)
      def __gettext__(:known_locales), do: unquote(known_locales)

      # The manifest lives in the root of the priv
      # directory that contains .po/.pot files.
      @external_resource unquote(Application.app_dir(otp_app, external_file))

      # This will be used when pluralizing in lngettext/6.
      @plural_forms unquote(plural_forms)

      if Gettext.Extractor.extracting? do
        Gettext.ExtractorAgent.add_backend(__MODULE__)
      end

      unquote(macros)
      unquote(compile_po_files(translations_dir))
      unquote(dynamic_clauses)
    end
  end

  defp macros do
    quote unquote: false do
      defmacro dgettext(domain, msgid, bindings \\ Macro.escape(%{})) do
        msgid = Gettext.Compiler.expand_to_binary(msgid, __MODULE__, __CALLER__)

        if Gettext.Extractor.extracting? do
          Gettext.Extractor.extract(__CALLER__, __MODULE__, domain, msgid)
        end

        quote do
          Gettext.dgettext(unquote(__MODULE__), unquote(domain), unquote(msgid), unquote(bindings))
        end
      end

      defmacro gettext(msgid, bindings \\ Macro.escape(%{})) do
        quote do
          unquote(__MODULE__).dgettext("default", unquote(msgid), unquote(bindings))
        end
      end

      defmacro dngettext(domain, msgid, msgid_plural, n, bindings \\ Macro.escape(%{})) do
        msgid        = Gettext.Compiler.expand_to_binary(msgid, __MODULE__, __CALLER__)
        msgid_plural = Gettext.Compiler.expand_to_binary(msgid_plural, __MODULE__, __CALLER__)

        if Gettext.Extractor.extracting? do
          Gettext.Extractor.extract(__CALLER__, __MODULE__, domain, {msgid, msgid_plural})
        end

        quote do
          Gettext.dngettext(
            unquote(__MODULE__),
            unquote(domain),
            unquote(msgid),
            unquote(msgid_plural),
            unquote(n),
            unquote(bindings)
          )
        end
      end

      defmacro ngettext(msgid, msgid_plural, n, bindings \\ Macro.escape(%{})) do
        quote do
          unquote(__MODULE__).dngettext(
            "default",
            unquote(msgid),
            unquote(msgid_plural),
            unquote(n),
            unquote(bindings)
          )
        end
      end
    end
  end

  @doc """
  Returns the function signatures of `lgettext/4` and `lngettext/6`.
  """
  @spec signatures() :: Macro.t
  def signatures do
    quote do
      def lgettext(locale, domain, msgid, bindings \\ %{})
      def lngettext(locale, domain, msgid, msgid_plural, n, bindings \\ %{})
    end
  end

  @doc """
  Returns the quoted code for the dynamic clauses of `lgettext/4` and
  `lngettext/6`.
  """
  @spec dynamic_clauses() :: Macro.t
  def dynamic_clauses do
    quote do
      def lgettext(_locale, domain, msgid, bindings) do
        Gettext.Compiler.warn_if_domain_contains_slashes(domain)

        case Gettext.Interpolation.interpolate(msgid, bindings) do
          {:ok, interpolated} -> {:default, interpolated}
          {:error, _} = error -> error
        end
      end

      def lngettext(_locale, domain, msgid, msgid_plural, n, bindings) do
        Gettext.Compiler.warn_if_domain_contains_slashes(domain)

        str      = if n == 1, do: msgid, else: msgid_plural
        bindings = Map.put(bindings, :count, n)

        case Gettext.Interpolation.interpolate(str, bindings) do
          {:ok, interpolated} -> {:default, interpolated}
          {:error, _} = error -> error
        end
      end
    end
  end

  # TODO Remove this once Elixir will fix ~s to expand to just a binary when
  #      there's no interpolation.
  @doc """
  Expands the given `msgid` in the given `env`, raising if it doesn't expand to
  a binary.

  This function doesn't just check that the expansion of `msgid` (via
  `Macro.expand/2`) is a binary; it also takes care of `{:<<>>, _, binaries}`
  ASTs (e.g., the `~s` sigil expands to such AST).
  """
  @spec expand_to_binary(binary, module, Macro.Env.t) :: binary | no_return
  def expand_to_binary(msgid, gettext_module, env) do
    raiser = fn ->
      raise ArgumentError, """
      *gettext macros expect translation keys (msgid and msgid_plural)
      to expand to strings at compile-time.

      Dynamic translations should be avoided as they limit gettext's
      ability to extract translations from your source code. If you are
      sure you need dynamic lookup, you can use the functions in the Gettext
      module:

          string = "hello world"
          Gettext.gettext(#{inspect gettext_module}, string)
      """
    end

    case Macro.expand(msgid, env) do
      msgid when is_binary(msgid) ->
        msgid
      {:<<>>, _, pieces} ->
        if Enum.all?(pieces, &is_binary/1), do: Enum.join(pieces, ""), else: raiser.()
      _ ->
        raiser.()
    end
  end

  @doc """
  Prints a warning on `:stderr` if `domain` contains slashes.

  This function is called by `lgettext` and `lngettext`.
  """
  @spec warn_if_domain_contains_slashes(binary) :: :ok
  def warn_if_domain_contains_slashes(domain) do
    if String.contains?(domain, "/") do
      IO.puts :stderr, "warning: slashes in domains are not supported: #{inspect domain}"
    end
  end

  @doc """
  Compiles all the `.po` files in the given directory (`dir`) into `lgettext/4`
  and `lngettext/6` function clauses.
  """
  @spec compile_po_files(Path.t) :: Macro.t
  def compile_po_files(dir) do
    Enum.reduce(po_files_in_dir(dir), [], &compile_po_file/2)
  end

  # `acc` is a list of already compiled translation, i.e., of quoted function
  # definitions. Here, we prepend a quoted function definition to that list for
  # each translation in the given PO file.
  defp compile_po_file(path, acc) do
    {locale, domain} = locale_and_domain_from_path(path)
    %PO{translations: translations} = PO.parse_file!(path)

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
    msgid  = IO.iodata_to_binary(t.msgid)
    msgstr = IO.iodata_to_binary(t.msgstr)

    # Only actually generate this function clause if the msgstr is not empty. If
    # it's empty, not generating this clause (by returning `nil` from this `if`)
    # means that the dynamic clause will be executed, returning `{:default,
    # msgid}` (with interpolation and so on).
    if msgstr != "" do
      quote do
        def lgettext(unquote(locale), unquote(domain), unquote(msgid), var!(bindings)) do
          unquote(compile_interpolation(msgstr))
        end
      end
    end
  end

  defp compile_translation(locale, domain, %PluralTranslation{} = t) do
    msgid        = IO.iodata_to_binary(t.msgid)
    msgid_plural = IO.iodata_to_binary(t.msgid_plural)

    msgstr = Enum.map(t.msgstr, fn {form, str} -> {form, IO.iodata_to_binary(str)} end)

    # If any of the msgstrs is empty, then we skip the generation of this
    # function clause. The reason we do this is the same as for the
    # `%Translation{}` clause.
    unless Enum.any?(msgstr, &match?({_, ""}, &1)) do
      clauses = Enum.map msgstr, fn({form, str}) ->
        {:->, [], [[form], compile_interpolation(str)]}
      end

      quote do
        def lngettext(unquote(locale), unquote(domain), unquote(msgid), unquote(msgid_plural), n, bindings) do
          # @plural_forms is defined in the current backend by
          # __before_compile__/1.
          plural_form    = @plural_forms.plural(unquote(locale), n)
          var!(bindings) = Map.put(bindings, :count, n)

          case plural_form, do: unquote(clauses)
        end
      end
    end
  end

  # Compiles a string into a full-blown `case` statement which interpolates the
  # string based on some bindings or returns an error in case those bindings are
  # missing. Note that the `bindings` variable is assumed to be in the scope by
  # the quoted code that is returned.
  defp compile_interpolation(str) do
    keys          = Interpolation.keys(str)
    match         = compile_interpolation_match(keys)
    interpolation = compile_interpolatable_string(str)

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
  defp compile_interpolatable_string(str) do
    Enum.reduce Interpolation.to_interpolatable(str), "", fn
      key, acc when is_atom(key) ->
        quote do: unquote(acc) <> to_string(unquote(Macro.var(key, __MODULE__)))
      str, acc ->
        quote do: unquote(acc) <> unquote(str)
    end
  end

  # Returns all the PO files in `translations_dir` (under "canonical" paths,
  # i.e., `locale/LC_MESSAGES/domain.po`).
  defp po_files_in_dir(dir) do
    dir
    |> Path.join(@po_wildcard)
    |> Path.wildcard()
  end

  # Returns all the locales in `translations_dir` (which are the locales known
  # by the compiled backend).
  defp known_locales(translations_dir) do
    case File.ls(translations_dir) do
      {:ok, files} ->
        Enum.filter(files, &File.dir?(Path.join(translations_dir, &1)))
      {:error, :enoent} ->
        []
      {:error, reason} ->
        raise File.Error, reason: reason, action: "list directory", path: translations_dir
    end
  end
end
