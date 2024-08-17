defmodule Gettext.Macros do
  @moduledoc false

  defmacro dpgettext_noop(domain, msgctxt, msgid) do
    domain = expand_domain(domain, __CALLER__)
    msgid = Gettext.Compiler.expand_to_binary(msgid, "msgid", __MODULE__, __CALLER__)
    msgctxt = Gettext.Compiler.expand_to_binary(msgctxt, "msgctxt", __MODULE__, __CALLER__)

    if Gettext.Extractor.extracting?() do
      Gettext.Extractor.extract(
        __CALLER__,
        __MODULE__,
        domain,
        msgctxt,
        msgid,
        Gettext.Compiler.get_and_flush_extracted_comments()
      )
    end

    msgid
  end

  defmacro dgettext_noop(domain, msgid) do
    quote do
      unquote(__MODULE__).dpgettext_noop(unquote(domain), nil, unquote(msgid))
    end
  end

  defmacro gettext_noop(msgid) do
    quote do
      unquote(__MODULE__).dpgettext_noop(
        {@__gettext_backend__, :__default_domain__},
        nil,
        unquote(msgid)
      )
    end
  end

  defmacro pgettext_noop(msgid, context) do
    quote do
      unquote(__MODULE__).dpgettext_noop(
        {@__gettext_backend__, :__default_domain__},
        unquote(context),
        unquote(msgid)
      )
    end
  end

  defmacro dpngettext_noop(domain, msgctxt, msgid, msgid_plural) do
    domain =
      case domain do
        {backend, :__default_domain__} when not is_nil(backend) ->
          Macro.expand(backend, __CALLER__).__gettext__(:default_domain)

        _other ->
          Gettext.Compiler.expand_to_binary(domain, "domain", __MODULE__, __CALLER__)
      end

    msgid = Gettext.Compiler.expand_to_binary(msgid, "msgid", __MODULE__, __CALLER__)
    msgctxt = Gettext.Compiler.expand_to_binary(msgctxt, "msgctxt", __MODULE__, __CALLER__)

    msgid_plural =
      Gettext.Compiler.expand_to_binary(msgid_plural, "msgid_plural", __MODULE__, __CALLER__)

    if Gettext.Extractor.extracting?() do
      Gettext.Extractor.extract(
        __CALLER__,
        __MODULE__,
        domain,
        msgctxt,
        {msgid, msgid_plural},
        Gettext.Compiler.get_and_flush_extracted_comments()
      )
    end

    {msgid, msgid_plural}
  end

  defmacro dngettext_noop(domain, msgid, msgid_plural) do
    quote do
      unquote(__MODULE__).dpngettext_noop(
        unquote(domain),
        nil,
        unquote(msgid),
        unquote(msgid_plural)
      )
    end
  end

  defmacro pngettext_noop(msgctxt, msgid, msgid_plural) do
    quote do
      unquote(__MODULE__).dpngettext_noop(
        {@__gettext_backend__, :__default_domain__},
        unquote(msgctxt),
        unquote(msgid),
        unquote(msgid_plural)
      )
    end
  end

  defmacro ngettext_noop(msgid, msgid_plural) do
    quote do
      unquote(__MODULE__).dpngettext_noop(
        {@__gettext_backend__, :__default_domain__},
        nil,
        unquote(msgid),
        unquote(msgid_plural)
      )
    end
  end

  defmacro dpgettext(domain, msgctxt, msgid, bindings \\ Macro.escape(%{})) do
    domain = expand_domain(domain, __CALLER__)

    quote do
      msgid =
        unquote(__MODULE__).dpgettext_noop(unquote(domain), unquote(msgctxt), unquote(msgid))

      Gettext.dpgettext(
        @__gettext_backend__,
        unquote(domain),
        unquote(msgctxt),
        msgid,
        unquote(bindings)
      )
    end
  end

  defmacro dgettext(domain, msgid, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpgettext(unquote(domain), nil, unquote(msgid), unquote(bindings))
    end
  end

  defmacro pgettext(msgctxt, msgid, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpgettext(
        {@__gettext_backend__, :__default_domain__},
        unquote(msgctxt),
        unquote(msgid),
        unquote(bindings)
      )
    end
  end

  defmacro gettext(msgid, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpgettext(
        {@__gettext_backend__, :__default_domain__},
        nil,
        unquote(msgid),
        unquote(bindings)
      )
    end
  end

  defmacro dpngettext(domain, msgctxt, msgid, msgid_plural, n, bindings \\ Macro.escape(%{})) do
    domain = expand_domain(domain, __CALLER__)

    quote do
      {msgid, msgid_plural} =
        unquote(__MODULE__).dpngettext_noop(
          unquote(domain),
          unquote(msgctxt),
          unquote(msgid),
          unquote(msgid_plural)
        )

      Gettext.dpngettext(
        @__gettext_backend__,
        unquote(domain),
        unquote(msgctxt),
        msgid,
        msgid_plural,
        unquote(n),
        unquote(bindings)
      )
    end
  end

  defmacro dngettext(domain, msgid, msgid_plural, n, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpngettext(
        unquote(domain),
        nil,
        unquote(msgid),
        unquote(msgid_plural),
        unquote(n),
        unquote(bindings)
      )
    end
  end

  defmacro ngettext(msgid, msgid_plural, n, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpngettext(
        {@__gettext_backend__, :__default_domain__},
        nil,
        unquote(msgid),
        unquote(msgid_plural),
        unquote(n),
        unquote(bindings)
      )
    end
  end

  defmacro pngettext(msgctxt, msgid, msgid_plural, n, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpngettext(
        {@__gettext_backend__, :__default_domain__},
        unquote(msgctxt),
        unquote(msgid),
        unquote(msgid_plural),
        unquote(n),
        unquote(bindings)
      )
    end
  end

  defmacro gettext_comment(comment) do
    comment = Gettext.Compiler.expand_to_binary(comment, "comment", __MODULE__, __CALLER__)
    Gettext.Compiler.append_extracted_comment(comment)
    :ok
  end

  defp expand_domain({backend, :__default_domain__}, env) do
    if Gettext.Extractor.extracting?() do
      Macro.expand(backend, env).__gettext__(:default_domain)
    else
      quote do
        unquote(backend).__gettext__(:default_domain)
      end
    end
  end

  defp expand_domain(domain, _env) do
    domain
  end
end
