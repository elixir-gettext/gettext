defmodule Gettext.Interpolation do
  @moduledoc """
  Behaviour to provide Gettext String Interpolation.
  """

  @type translation_type :: :translation | :plural_translation

  @callback runtime_interpolate(message :: String.t(), bindings :: map) ::
              {:ok, String.t()}
              | {:mssing_bindings, message :: String.t(), missing_bindings :: [atom]}

  @macrocallback compile_interpolate(
                   translation_type :: translation_type,
                   message :: String.t(),
                   bindings :: map()
                 ) :: Macro.t()

  @doc """
  Defines the gettext message format
  https://www.gnu.org/software/gettext/manual/html_node/PO-Files.html#index-msgstr
  """
  @callback message_format :: String.t()
end
