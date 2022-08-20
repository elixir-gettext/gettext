defmodule Gettext.Repo do
  @moduledoc """
  A module that implements this behaviour loads translation strings.
  """

  @type locale() :: binary()
  @type domain() :: binary()
  @type msgctxt() :: binary() | nil
  @type msgid() :: binary()
  @type plural_form() :: integer()
  @type msgstr() :: binary()
  @type opts() :: term()

  @doc """
  Called at compile time to configure the repository.
  """
  @callback init(opts()) :: opts()

  @doc """
  Should return a singular translation string.
  """
  @callback get_translation(locale(), domain(), msgctxt(), msgid(), opts()) ::
              {:ok, msgstr()} | :not_found

  @doc """
  Should return a plural translation string.
  """
  @callback get_plural_translation(locale(), domain(), msgctxt(), msgid(), plural_form(), opts()) ::
              {:ok, msgstr()} | :not_found
end
