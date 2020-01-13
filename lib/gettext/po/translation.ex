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

  This struct contains the following fields:

    * `msgid` - the id of the translation.
    * `msgstr` - the translated string.
    * `comments` - a list of comments as they are found in the PO file (for example,
      `["# foo"]`).
    * `extracted_comments` - a list of extracted comments (for example,
      `["#. foo", "#. bar"]`).
    * `references` - a list of references (files this translation comes from) in
      the form `{file, line}`.
    * `flags` - a set of flags for this translation.
    * `po_source_line` - the line this translation is on in the PO file where it
      comes from.

  """

  @type t :: %__MODULE__{
          msgid: [binary],
          msgstr: [binary],
          msgctxt: [binary] | nil,
          comments: [binary],
          extracted_comments: [binary],
          references: [{binary, pos_integer}],
          flags: MapSet.t(),
          po_source_line: pos_integer
        }

  @enforce_keys [:msgid]

  defstruct msgid: nil,
            msgstr: [],
            msgctxt: nil,
            comments: [],
            extracted_comments: [],
            references: [],
            flags: MapSet.new(),
            po_source_line: 1
end
