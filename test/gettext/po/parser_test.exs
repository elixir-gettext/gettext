defmodule Gettext.PO.ParserTest do
  use ExUnit.Case

  alias Gettext.PO.Parser
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  test "parse/1 with single strings" do
    parsed =
      parse("""
      msgid "hello"
      msgstr "ciao"
      """)

    assert {:ok, [], [], [%Translation{msgid: ["hello"], msgstr: ["ciao"]}]} = parsed
  end

  test "parse/1 with multiple concatenated strings" do
    parsed =
      parse("""
      msgid "hello" " world"
      msgstr "ciao" " mondo"
      """)

    assert {:ok, [], [], [translation]} = parsed
    assert %Translation{msgid: ["hello", " world"], msgstr: ["ciao", " mondo"]} = translation
  end

  test "parse/1 with multiple translations" do
    parsed =
      parse("""
      msgid "hello"
      msgstr "ciao"
      msgid "word"
      msgstr "parola"
      """)

    assert {:ok, [], [],
            [
              %Translation{msgid: ["hello"], msgstr: ["ciao"]},
              %Translation{msgid: ["word"], msgstr: ["parola"]}
            ]} = parsed
  end

  test "parse/1 with unicode characters in the strings" do
    parsed =
      parse("""
      msgid "føø"
      msgstr "bårπ"
      """)

    assert {:ok, [], [], [%Translation{msgid: ["føø"], msgstr: ["bårπ"]}]} = parsed
  end

  test "parse/1 with a pluralized string" do
    parsed =
      parse("""
      msgid "foo"
      msgid_plural "foos"
      msgstr[0] "bar"
      msgstr[1] "bars"
      msgstr[2] "barres"
      """)

    assert {:ok, [], [], [translation]} = parsed

    assert %PluralTranslation{
             msgid: ["foo"],
             msgid_plural: ["foos"],
             msgstr: %{
               0 => ["bar"],
               1 => ["bars"],
               2 => ["barres"]
             }
           } = translation
  end

  test "comments are associated with translations" do
    parsed =
      parse("""
      # This is a translation
      #: lib/foo.ex:32
      # Ah, another comment!
      #. An extracted comment
      msgid "foo"
      msgstr "bar"
      """)

    assert {:ok, [], [],
            [
              %Translation{
                msgid: ["foo"],
                msgstr: ["bar"],
                comments: [
                  "# This is a translation",
                  "# Ah, another comment!"
                ],
                extracted_comments: ["#. An extracted comment"],
                references: [{"lib/foo.ex", 32}]
              }
            ]} = parsed
  end

  test "comments always belong to the next translation" do
    parsed =
      parse("""
      msgid "a"
      msgstr "b"
      # Comment
      msgid "c"
      msgstr "d"
      """)

    assert {:ok, [], [],
            [
              %Translation{msgid: ["a"], msgstr: ["b"]},
              %Translation{msgid: ["c"], msgstr: ["d"], comments: ["# Comment"]}
            ]} = parsed
  end

  test "syntax error when there is no 'msgid'" do
    parsed = parse("msgstr \"foo\"")
    assert {:error, 1, _} = parsed

    parsed = parse("\"foo\"")
    assert {:error, 1, _} = parsed
  end

  test "if there's a msgid_plural, then plural forms must follow" do
    parsed =
      parse("""
      msgid "foo"
      msgid_plural "foos"
      msgstr "bar"
      """)

    assert parsed == {:error, 3, "syntax error before: \"bar\""}
  end

  test "'msgid_plural' must come after 'msgid'" do
    parsed = parse("msgid_plural ")
    assert parsed == {:error, 1, "syntax error before: msgid_plural"}
  end

  test "comments can't be placed between 'msgid' and 'msgstr'" do
    parsed =
      parse("""
      msgid "foo"
      # Comment
      msgstr "bar"
      """)

    assert parsed == {:error, 2, "syntax error before: \"# Comment\""}

    parsed =
      parse("""
      msgid "foo"
      msgid_plural "foo"
      # Comment
      msgstr[0] "bar"
      """)

    assert parsed == {:error, 3, "syntax error before: \"# Comment\""}
  end

  test "files with just comments are ok (the comments are discarded)" do
    parsed =
      parse("""
      # A comment
      # Another comment
      """)

    assert parsed == {:ok, [], [], []}
  end

  test "reference are extracted into the :reference field of a translation" do
    parsed =
      parse("""
      #: foo.ex:1
      #: filename with spaces.ex:12
      # Not a reference comment
      # : Not a reference comment either
      #: another/ref/comment.ex:83
      msgid "foo"
      msgstr "bar"
      """)

    assert {:ok, [], [], [%Translation{} = t]} = parsed

    assert t.references == [
             {"foo.ex", 1},
             {"filename with spaces.ex", 12},
             {"another/ref/comment.ex", 83}
           ]

    # All the reference comments are removed.
    assert t.comments == [
             "# Not a reference comment",
             "# : Not a reference comment either"
           ]
  end

  test "extracted comments are extracted into the :extracted_comments field of a translation" do
    parsed =
      parse("""
      #. Extracted comment
      # Not an extracted comment
      #.Another extracted comment
      msgid "foo"
      msgstr "bar"
      """)

    assert {:ok, [], [], [%Translation{} = t]} = parsed

    assert t.extracted_comments == [
             "#. Extracted comment",
             "#.Another extracted comment"
           ]

    # All the reference comments are removed.
    assert t.comments == [
             "# Not an extracted comment"
           ]
  end

  test "flags are extracted in to the :flags field of a translation" do
    parsed =
      parse("""
      #, flag,a-flag b-flag, c-flag
      # comment
      #, flag,  ,d-flag ,, e-flag
      msgid "foo"
      msgstr "bar"
      """)

    assert {:ok, [], [], [%Translation{} = t]} = parsed
    assert Enum.sort(t.flags) == ~w(a-flag b-flag c-flag d-flag e-flag flag)
    assert t.comments == ["# comment"]
  end

  test "the line of a translation is the line of its msgid" do
    parsed =
      parse("""


      msgid "foo"
      msgstr "bar"
      """)

    {:ok, [], [], [%Translation{} = translation]} = parsed
    assert translation.po_source_line == 3
  end

  test "the line of a plural translation is the line of its msgid" do
    parsed =
      parse("""


      msgid "foo"
      msgid_plural "foos"
      msgstr[0] "bar"
      """)

    {:ok, [], [], [%PluralTranslation{} = translation]} = parsed
    assert translation.po_source_line == 3
  end

  test "headers are parsed when present" do
    parsed =
      parse(~S"""
      msgid ""
      msgstr "Language: en_US\n"
             "Last-Translator: Jane Doe <jane@doe.com>\n"
      """)

    assert parsed ==
             {
               :ok,
               [],
               ["Language: en_US\n", "Last-Translator: Jane Doe <jane@doe.com>\n"],
               []
             }
  end

  test "duplicated translations cause a parse error" do
    parsed =
      parse("""
      msgid "foo"
      msgstr "bar"

      msgid "foo"
      msgstr "baz"

      msgid "foo"
      msgstr "bong"
      """)

    assert parsed == {:error, 4, "found duplicate on line 1 for msgid: 'foo'"}

    # Works if the msgid is split differently as well
    parsed =
      parse("""
      msgid "foo" ""
      msgstr "bar"

      msgid "" "foo"
      msgstr "baz"
      """)

    assert parsed == {:error, 4, "found duplicate on line 1 for msgid: 'foo'"}
  end

  test "duplicated plural translations cause a parse error" do
    parsed =
      parse("""
      msgid "foo"
      msgid_plural "foos"
      msgstr[0] "bar"

      msgid "foo"
      msgid_plural "foos"
      msgstr[0] "baz"
      """)

    message = "found duplicate on line 1 for msgid: 'foo' and msgid_plural: 'foos'"
    assert parsed == {:error, 5, message}
  end

  test "an empty list of tokens is parsed as an empty list of translations" do
    assert parse("") == {:ok, [], [], []}
  end

  test "multiple references on the same line are parsed correctly" do
    parsed =
      parse("""
      #: foo.ex:1 bar.ex:2 with spaces.ex:3
      #: baz.ex:3 with:colon.ex:12
      msgid "foo"
      msgstr "bar"
      """)

    assert {:ok, [], [], [%Translation{} = t]} = parsed

    assert t.references == [
             {"foo.ex", 1},
             {"bar.ex", 2},
             {"with spaces.ex", 3},
             {"baz.ex", 3},
             {"with:colon.ex", 12}
           ]
  end

  test "top-of-the-file comments are extracted correctly" do
    parsed =
      parse("""
      # Top of the file
      ## Top of the file with two hashes
      msgid ""
      msgstr "Language: en_US\\n"
      """)

    assert {
             :ok,
             ["# Top of the file", "## Top of the file with two hashes"],
             ["Language: en_US\n"],
             []
           } = parsed
  end

  test "msgctxt is parsed correctly for translations" do
    parsed =
      parse("""
      msgctxt "my_" "context"
      msgid "my_msgid"
      msgstr "my_msgstr"
      """)

    assert {:ok, [], [], [%Translation{} = translation]} = parsed
    assert translation.msgctxt == ["my_", "context"]
    assert translation.msgid == ["my_msgid"]
    assert translation.msgstr == ["my_msgstr"]
  end

  test "msgctxt is parsed correctly for plural translations" do
    parsed =
      parse("""
      msgctxt "my_" "context"
      msgid "my_msgid"
      msgid_plural "my_msgid_plural"
      msgstr[0] "my_msgstr"
      """)

    assert {:ok, [], [], [%PluralTranslation{} = translation]} = parsed
    assert translation.msgctxt == ["my_", "context"]
    assert translation.msgid == ["my_msgid"]
    assert translation.msgid_plural == ["my_msgid_plural"]
    assert translation.msgstr[0] == ["my_msgstr"]
  end

  test "msgctxt is nil when no msgctxt is present in a translation" do
    parsed =
      parse("""
      msgid "my_msgid"
      msgstr "my_msgstr"
      """)

    assert {:ok, [], [], [%Translation{} = translation]} = parsed
    assert translation.msgctxt == nil
  end

  test "msgctxt causes a syntax error when misplaced" do
    # Badly placed msgctxt still causes a syntax error
    parsed =
      parse("""
      msgid "my_msgid"
      msgctxt "my_context"
      msgstr "my_msgstr"
      """)

    assert parsed == {:error, 2, "syntax error before: msgctxt"}
  end

  test "msgctxt should not cause duplication translations" do
    parsed =
      parse("""
      msgctxt "my_" "context"
      msgid "my_msgid"
      msgstr "my_msgstr"

      msgid "my_msgid"
      msgstr "my_msgstr"
      """)

    assert {:ok, [], [], [%Translation{} = translation, %Translation{} = translation2]} = parsed
    assert translation.msgctxt == ["my_", "context"]
    assert translation.msgid == ["my_msgid"]
    assert translation.msgstr == ["my_msgstr"]

    assert translation2.msgctxt == nil
    assert translation2.msgid == ["my_msgid"]
    assert translation2.msgstr == ["my_msgstr"]
  end

  test "msgctxt should not cause duplication for plural translations" do
    parsed =
      parse("""
      msgctxt "my_" "context"
      msgid "my_msgid"
      msgid_plural "my_msgid_plural"
      msgstr[0] "my_msgstr"

      msgid "my_msgid"
      msgid_plural "my_msgid_plural"
      msgstr[0] "my_msgstr"
      """)

    assert {:ok, [], [],
            [%PluralTranslation{} = translation, %PluralTranslation{} = translation2]} = parsed

    assert translation.msgctxt == ["my_", "context"]
    assert translation.msgid == ["my_msgid"]
    assert translation.msgid_plural == ["my_msgid_plural"]
    assert translation.msgstr[0] == ["my_msgstr"]

    assert translation2.msgctxt == nil
    assert translation2.msgid == ["my_msgid"]
    assert translation2.msgid_plural == ["my_msgid_plural"]
    assert translation2.msgstr[0] == ["my_msgstr"]
  end

  test "tokens are printed as Elixir terms, not Erlang terms" do
    parsed =
      parse("""
      msgid ""
      # comment
      """)

    assert {:error, _line, msg} = parsed
    assert msg == "syntax error before: \"# comment\""
  end

  defp parse(string) do
    {:ok, tokens} = Gettext.PO.Tokenizer.tokenize(string)
    Parser.parse(tokens)
  end
end
