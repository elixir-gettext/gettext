defmodule Gettext.PO.Translation do
  @moduledoc """
  A struct that holds information on a translation.

  This struct describes a translation that has no plural form, such as the one
  in the following snippet of `.po` file:

      msgid "Hello world!"
      msgstr "Ciao mondo!"

  For translations with a plural form, there's the
  `Gettext.PO.PluralTranslation` struct.

  This struct contains two fields:

    * `msgid` - the id of the translation
    * `msgstr` - the translated string

  """

  @type t :: %__MODULE__{
    msgid: binary,
    msgstr: binary,
  }

  defstruct [:msgid, :msgstr]
end
