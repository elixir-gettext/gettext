defmodule Gettext.PO.Translation do
  @moduledoc """
  A struct that holds information on a translation.

  This struct describes a translation that has no plural form, such as the one
  in the following snippet of `.po` file:

      msgid "Hello world!"
      msgstr "Ciao mondo!"

  Translations with a plural form are not represented as
  `Gettext.PO.Translation` structs, but as `Gettext.PO.PluralTranslation`
  structs.

  This struct contains two fields:

    * `msgid` - the id of the translation.
    * `msgstr` - the translated string.

  """

  @type t :: %__MODULE__{
    msgid: binary,
    msgstr: binary,
  }

  defstruct [:msgid, :msgstr]
end
