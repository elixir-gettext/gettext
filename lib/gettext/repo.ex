defmodule Gettext.Repo do
  @moduledoc """
  A behaviour for modules that can fetch Gettext translations.
  """

  @type locale() :: String.t()
  @type domain() :: String.t()
  @type msgctxt() :: String.t() | nil
  @type msgid() :: String.t()
  @type msgid_plural() :: String.t()
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
  @callback get_plural_translation(locale(), domain(), msgctxt(), msgid(), msgid_plural(), plural_form(), opts()) ::
              {:ok, msgstr()} | :not_found
end
