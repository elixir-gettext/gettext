defmodule Gettext.Macros do
  @moduledoc """
  Macros used by Gettext to provide the gettext family of functions.

  *Available since v0.26.0.*

  Macros enable users to use gettext and get **automatic extraction** of translations.
  See `Gettext` for more information.

  This module is *imported* every time you call:

      use Gettext, backend: MyApp.Gettext

  > #### Warning {: .error}
  >
  > You are not meant to use this module in any way other than with `use Gettext` as shown above,
  > as its macros depend on internals that get set up when you call `use Gettext`.
  """

  @moduledoc since: "0.26.0"

  @doc false
  def __expand_runtime_domain__(backend, :default), do: backend.__gettext__(:default_domain)
  def __expand_runtime_domain__(_backend, domain) when is_binary(domain), do: domain

  @doc """
  Marks the given message for extraction and returns it unchanged.

  This macro can be used to mark a message for extraction when `mix
  gettext.extract` is run. The return value is the given string, so that this
  macro can be used seamlessly in place of the string to extract.

  ## Examples

      dpgettext_noop("errors", "Home page", "Error found!")
      #=> "Error found!"

  """
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

  @doc """
  Marks the given message for extraction and returns it unchanged.

  This macro can be used to mark a message for extraction when `mix
  gettext.extract` is run. The return value is the given string, so that this
  macro can be used seamlessly in place of the string to extract.

  ## Examples

      dgettext_noop("errors", "Error found!")
      #=> "Error found!"

  """
  defmacro dgettext_noop(domain, msgid) do
    quote do
      unquote(__MODULE__).dpgettext_noop(unquote(domain), nil, unquote(msgid))
    end
  end

  @doc """
  Marks the given message for extraction and returns it unchanged.

  This macro can be used to mark a message for extraction when `mix
  gettext.extract` is run. The return value is the given string, so that this
  macro can be used seamlessly in place of the string to extract.

  ## Examples

      gettext_noop("Error found!")
      #=> "Error found!"

  """
  defmacro gettext_noop(msgid) do
    quote do
      unquote(__MODULE__).dpgettext_noop(:default, nil, unquote(msgid))
    end
  end

  @doc """
  Marks the given message for extraction and returns it unchanged.

  This macro can be used to mark a message for extraction when `mix
  gettext.extract` is run. The return value is the given string, so that this
  macro can be used seamlessly in place of the string to extract.

  ## Examples

      pgettext_noop("Error found!", "Home page")
      #=> "Error found!"

  """
  defmacro pgettext_noop(msgid, context) do
    quote do
      unquote(__MODULE__).dpgettext_noop(:default, unquote(context), unquote(msgid))
    end
  end

  @doc """
  Marks the given message for extraction and returns it unchanged.

  This macro can be used to mark a message for extraction when `mix
  gettext.extract` is run. The return value is the given string, so that this
  macro can be used seamlessly in place of the string to extract.

  ## Examples

      dpngettext_noop("errors", "Home page", "Error found!", "Errors found!")
      #=> "Error found!"

  """
  defmacro dpngettext_noop(domain, msgctxt, msgid, msgid_plural) do
    domain = expand_domain(domain, __CALLER__)
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

  @doc """
  Marks the given message for extraction and returns
  `{msgid, msgid_plural}`.

  This macro can be used to mark a message for extraction when `mix
  gettext.extract` is run. The return value of this macro is `{msgid,
  msgid_plural}`.

  ## Examples

      my_fun = fn {msgid, msgid_plural} ->
        # do something with msgid and msgid_plural
      end

      my_fun.(dngettext_noop("errors", "One error", "%{count} errors"))

  """
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

  @doc """
  Marks the given message for extraction and returns it unchanged.

  This macro can be used to mark a message for extraction when `mix
  gettext.extract` is run. The return value is the given string, so that this
  macro can be used seamlessly in place of the string to extract.

  ## Examples

      pngettext_noop("Home page", "Error found!", "Errors found!")
      #=> "Error found!"

  """
  defmacro pngettext_noop(msgctxt, msgid, msgid_plural) do
    quote do
      unquote(__MODULE__).dpngettext_noop(
        :default,
        unquote(msgctxt),
        unquote(msgid),
        unquote(msgid_plural)
      )
    end
  end

  @doc """
  Same as `dngettext_noop("default", msgid, mgsid_plural)`, but will use a
  per-backend configured default domain if provided.
  """
  defmacro ngettext_noop(msgid, msgid_plural) do
    quote do
      unquote(__MODULE__).dpngettext_noop(:default, nil, unquote(msgid), unquote(msgid_plural))
    end
  end

  @doc """
  Translates the given `msgid` with a given context (`msgctxt`) in the given `domain`.

  `bindings` is a map of bindings to support interpolation.

  See also `Gettext.dpgettext/5`.
  """
  defmacro dpgettext(domain, msgctxt, msgid, bindings \\ Macro.escape(%{})) do
    domain = expand_domain(domain, __CALLER__)

    quote do
      msgid =
        unquote(__MODULE__).dpgettext_noop(unquote(domain), unquote(msgctxt), unquote(msgid))

      Gettext.dpgettext(
        @__gettext_backend__,
        unquote(__MODULE__).__expand_runtime_domain__(@__gettext_backend__, unquote(domain)),
        unquote(msgctxt),
        msgid,
        unquote(bindings)
      )
    end
  end

  @doc """
  Translates the given `msgid` in the given `domain`.

  `bindings` is a map of bindings to support interpolation.

  See also `Gettext.dgettext/4`.
  """
  defmacro dgettext(domain, msgid, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpgettext(unquote(domain), nil, unquote(msgid), unquote(bindings))
    end
  end

  @doc """
  Translates the given `msgid` with the given context (`msgctxt`).

  `bindings` is a map of bindings to support interpolation.

  See also `Gettext.pgettext/4`.
  """
  defmacro pgettext(msgctxt, msgid, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpgettext(
        :default,
        unquote(msgctxt),
        unquote(msgid),
        unquote(bindings)
      )
    end
  end

  @doc """
  Same as `dgettext("default", msgid, %{})`, but will use a per-backend
  configured default domain if provided.

  See also `Gettext.gettext/3`.
  """
  defmacro gettext(msgid, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpgettext(:default, nil, unquote(msgid), unquote(bindings))
    end
  end

  @doc """
  Translates the given plural message (`msgid` + `msgid_plural`) with the given context (`msgctxt`)
  in the given `domain`.

  `n` is an integer used to determine how to pluralize the
  message. `bindings` is a map of bindings to support interpolation.

  See also `Gettext.dpngettext/7`.
  """
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
        unquote(__MODULE__).__expand_runtime_domain__(@__gettext_backend__, unquote(domain)),
        unquote(msgctxt),
        msgid,
        msgid_plural,
        unquote(n),
        unquote(bindings)
      )
    end
  end

  @doc """
  Translates the given plural message (`msgid` + `msgid_plural`) in the
  given `domain`.

  `n` is an integer used to determine how to pluralize the
  message. `bindings` is a map of bindings to support interpolation.

  See also `Gettext.dngettext/6`.
  """
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

  @doc """
  Same as `dngettext("default", msgid, msgid_plural, n, bindings)`, but will
  use a per-backend configured default domain if provided.

  See also `Gettext.ngettext/5`.
  """
  defmacro ngettext(msgid, msgid_plural, n, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpngettext(
        :default,
        nil,
        unquote(msgid),
        unquote(msgid_plural),
        unquote(n),
        unquote(bindings)
      )
    end
  end

  @doc """
  Translates the given plural message (`msgid` + `msgid_plural`) with the given context (`msgctxt`).

  `n` is an integer used to determine how to pluralize the
  message. `bindings` is a map of bindings to support interpolation.

  See also `Gettext.pngettext/6`.
  """
  defmacro pngettext(msgctxt, msgid, msgid_plural, n, bindings \\ Macro.escape(%{})) do
    quote do
      unquote(__MODULE__).dpngettext(
        :default,
        unquote(msgctxt),
        unquote(msgid),
        unquote(msgid_plural),
        unquote(n),
        unquote(bindings)
      )
    end
  end

  @doc """
  Stores an "extracted comment" for the next message.

  This macro can be used to add comments (Gettext refers to such
  comments as *extracted comments*) to the next message that will
  be extracted. Extracted comments will be prefixed with `#.` in POT
  files.

  Calling this function multiple times will accumulate the comments;
  when another Gettext macro (such as `gettext/2`) is called,
  the comments will be extracted and attached to that message, and
  they will be flushed so as to start again.

  This macro always returns `:ok`.

  ## Examples

      gettext_comment("The next message is awesome")
      gettext_comment("Another comment for the next message")
      gettext("The awesome message")

  """
  defmacro gettext_comment(comment) do
    comment = Gettext.Compiler.expand_to_binary(comment, "comment", __MODULE__, __CALLER__)
    Gettext.Compiler.append_extracted_comment(comment)
    :ok
  end

  defp expand_domain(:default, _env) do
    :default
  end

  defp expand_domain(domain, env) do
    Gettext.Compiler.expand_to_binary(domain, "domain", __MODULE__, env)
  end
end
