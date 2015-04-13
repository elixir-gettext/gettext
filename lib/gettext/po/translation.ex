defmodule Gettext.PO.Translation do
  @moduledoc """
  A struct that holds information on a translation.

  The `Translation` struct contains three fields:

    * `msgid` - the id of the translation
    * `msgid_plural` - the plural id of the translation
    * `msgstr` - the translated string if there's no pluralization, otherwise a
      map with plural forms as keys (`0`, `1` and so on) and plural strings as
      corresponding values

  """

  @type t :: %__MODULE__{
    msgid: binary,
    msgid_plural: binary,
    msgstr: binary | Map.t,
  }

  defstruct [:msgid, :msgid_plural, :msgstr]
end
