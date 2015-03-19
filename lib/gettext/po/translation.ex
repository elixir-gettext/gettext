defmodule Gettext.PO.Translation do
  @moduledoc """
  A struct that holds information on a translation.

  The `Translation` struct contains two fields:

    * `msgid` - the id of the translation
    * `msgstr` - the translated string

  """

  defstruct [:msgid, :msgstr]
end
