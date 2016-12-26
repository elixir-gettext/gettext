defmodule Gettext.PO.ParserTest do
  use ExUnit.Case

  alias Gettext.PO.Parser
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  test "parse/1 with single strings" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "hello"},
      {:msgstr, 2}, {:str, 2, "ciao"}
    ])

    assert {:ok, [], [], [%Translation{msgid: ["hello"], msgstr: ["ciao"]}]} = parsed
  end

  test "parse/1 with multiple concatenated strings" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "hello"}, {:str, 1, " world"},
      {:msgstr, 2}, {:str, 2, "ciao"}, {:str, 3, " mondo"}
    ])

    assert {:ok, [], [], [
      %Translation{msgid: ["hello", " world"], msgstr: ["ciao", " mondo"]}
    ]} = parsed
  end

  test "parse/1 with multiple translations" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "hello"},
      {:msgstr, 2}, {:str, 2, "ciao"},
      {:msgid, 3}, {:str, 3, "word"},
      {:msgstr, 4}, {:str, 4, "parola"},
    ])

    assert {:ok, [], [], [
      %Translation{msgid: ["hello"], msgstr: ["ciao"]},
      %Translation{msgid: ["word"], msgstr: ["parola"]},
    ]} = parsed
  end

  test "parse/1 with unicode characters in the strings" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "føø"},
      {:msgstr, 2}, {:str, 2, "bårπ"},
    ])

    assert {:ok, [], [], [%Translation{msgid: ["føø"], msgstr: ["bårπ"]}]} = parsed
  end

  test "parse/1 with a pluralized string" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "foo"},
      {:msgid_plural, 1}, {:str, 1, "foos"},
      {:msgstr, 1}, {:plural_form, 1, 0}, {:str, 1, "bar"},
      {:msgstr, 1}, {:plural_form, 1, 1}, {:str, 1, "bars"},
      {:msgstr, 1}, {:plural_form, 1, 2}, {:str, 1, "barres"},
    ])

    assert {:ok, [], [], [%PluralTranslation{
      msgid: ["foo"],
      msgid_plural: ["foos"],
      msgstr: %{
        0 => ["bar"],
        1 => ["bars"],
        2 => ["barres"],
      },
    }]} = parsed
  end

  test "comments are associated with translations" do
    parsed = Parser.parse([
      {:comment, 1, "# This is a translation"},
      {:comment, 2, "#: lib/foo.ex:32"},
      {:comment, 3, "# Ah, another comment!"},
      {:msgid, 4}, {:str, 4, "foo"},
      {:msgstr, 5}, {:str, 5, "bar"},
    ])

    assert {:ok, [], [], [%Translation{
      msgid: ["foo"],
      msgstr: ["bar"],
      comments: [
        "# This is a translation",
        "# Ah, another comment!",
      ],
      references: [{"lib/foo.ex", 32}],
    }]} = parsed
  end

  test "comments always belong to the next translation" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "a"},
      {:msgstr, 3}, {:str, 3, "b"},
      {:comment, 2, "# Comment"},
      {:msgid, 1}, {:str, 1, "c"},
      {:msgstr, 3}, {:str, 3, "d"},
    ])

    assert {:ok, [], [], [
      %Translation{msgid: ["a"], msgstr: ["b"]},
      %Translation{msgid: ["c"], msgstr: ["d"], comments: ["# Comment"]},
    ]} = parsed
  end

  test "syntax error when there is no 'msgid'" do
    parsed = Parser.parse [{:msgstr, 1}, {:str, 1, "foo"}]
    assert {:error, 1, _} = parsed

    parsed = Parser.parse [{:str, 1, "foo"}]
    assert {:error, 1, _} = parsed
  end

  test "if there's a msgid_plural, then plural forms must follow" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "foo"},
      {:msgid_plural, 1}, {:str, 1, "foos"},
      {:msgstr, 1}, {:str, 1, "bar"},
    ])

    assert parsed == {:error, 1, "syntax error before: \"bar\""}
  end

  test "'msgid_plural' must come after 'msgid'" do
    parsed = Parser.parse([{:msgid_plural, 1}])
    assert parsed == {:error, 1, "syntax error before: msgid_plural"}
  end

  test "comments can't be placed between 'msgid' and 'msgstr'" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "foo"},
      {:comment, 2, "# Comment"},
      {:msgstr, 3}, {:str, 3, "bar"},
    ])
    assert {:error, 2, _} = parsed

    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "foo"},
      {:msgid_plural, 2}, {:str, 1, "foo"},
      {:comment, 3, "# Comment"},
      {:msgstr, 4}, {:plural_form, 4, 0}, {:str, 4, "bar"},
    ])
    assert {:error, 3, _} = parsed
  end

  test "files with just comments are ok (the comments are discarded)" do
    parsed = Parser.parse([
      {:comment, 1, "# A comment"},
      {:comment, 2, "# Another comment"},
    ])

    assert {:ok, [], [], []} = parsed
  end

  test "reference are extracted into the :reference field of a translation" do
    parsed = Parser.parse([
      {:comment, 1, "#: foo.ex:1 "},
      {:comment, 1, "#: filename with spaces.ex:12"},
      {:comment, 1, "# Not a reference comment"},
      {:comment, 1, "# : Not a reference comment either"},
      {:comment, 1, "#: another/ref/comment.ex:83"},
      {:msgid, 1}, {:str, 1, "foo"},
      {:msgstr, 1}, {:str, 3, "bar"},
    ])

    assert {:ok, [], [], [%Translation{} = t]} = parsed
    assert t.references == [
      {"foo.ex", 1},
      {"filename with spaces.ex", 12},
      {"another/ref/comment.ex", 83},
    ]
    # All the reference comments are removed.
    assert t.comments == [
      "# Not a reference comment",
      "# : Not a reference comment either",
    ]
  end

  test "flags are extracted in to the :flags field of a translation" do
    parsed = Parser.parse([
      {:comment, 1, "#, flag other-flag"},
      {:comment, 2, "# comment"},
      {:comment, 3, "#, other-flag other-other-flag"},
      {:msgid, 4}, {:str, 4, "foo"},
      {:msgstr, 5}, {:str, 5, "bar"},
    ])

    assert {:ok, [], [], [%Translation{} = t]} = parsed
    assert Enum.sort(t.flags) == ~w(flag other-flag other-other-flag)
    assert t.comments == ["# comment"]
  end

  test "the line of a translation is the line of its msgid" do
    parsed = Parser.parse([
      {:msgid, 10}, {:str, 10, "foo"},
      {:msgstr, 11}, {:str, 11, "bar"},
    ])

    {:ok, [], [], [%Translation{} = translation]} = parsed
    assert translation.po_source_line == 10
  end

  test "the line of a plural translation is the line of its msgid" do
    parsed = Parser.parse([
      {:msgid, 10}, {:str, 10, "foo"},
      {:msgid_plural, 11}, {:str, 11, "foos"},
      {:msgstr, 12}, {:plural_form, 12, 0}, {:str, 12, "bar"},
    ])

    {:ok, [], [], [%PluralTranslation{} = translation]} = parsed
    assert translation.po_source_line == 10
  end

  test "headers are parsed when present" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, ""},
      {:msgstr, 1},
        {:str, 1, "Language: en_US\n"},
        {:str, 1, "Last-Translator: Jane Doe <jane@doe.com>\n"}
    ])

    assert parsed == {
      :ok,
      [],
      ["Language: en_US\n", "Last-Translator: Jane Doe <jane@doe.com>\n"],
      []
    }
  end

  test "duplicated translations cause a parse error" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "foo"}, {:msgstr, 1}, {:str, 1, "bar"},
      {:msgid, 2}, {:str, 2, "foo"}, {:msgstr, 2}, {:str, 2, "baz"},
      {:msgid, 3}, {:str, 3, "foo"}, {:msgstr, 3}, {:str, 3, "bong"},
    ])

    msg = "found duplicate on line 1 for msgid: 'foo'"
    assert parsed == {:error, 2, msg}

    # Works if the msgid is split differently as well
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "foo"}, {:str, 1, ""}, {:msgstr, 1}, {:str, 1, "bar"},
      {:msgid, 2}, {:str, 2, ""}, {:str, 2, "foo"}, {:msgstr, 2}, {:str, 2, "baz"},
    ])

    msg = "found duplicate on line 1 for msgid: 'foo'"
    assert parsed == {:error, 2, msg}
  end

  test "duplicated plural translations cause a parse error" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "foo"}, {:msgid_plural, 1}, {:str, 1, "foos"},
        {:msgstr, 1}, {:plural_form, 1, 0}, {:str, 1, "bar"},
      {:msgid, 2}, {:str, 2, "foo"}, {:msgid_plural, 2}, {:str, 2, "foos"},
        {:msgstr, 2}, {:plural_form, 2, 0}, {:str, 2, "baz"},
    ])

    msg = "found duplicate on line 1 for msgid: 'foo' and msgid_plural: 'foos'"
    assert parsed == {:error, 2, msg}
  end

  test "an empty list of tokens is parsed as an empty list of translations" do
    assert Parser.parse([]) == {:ok, [], [], []}
  end

  test "multiple references on the same line are parsed correctly" do
    parsed = Parser.parse([
      {:comment, 1, "#: foo.ex:1 bar.ex:2 with spaces.ex:3"},
      {:comment, 2, "#: baz.ex:3"},
      {:msgid, 3}, {:str, 3, "foo"}, {:msgstr, 3}, {:str, 3, "bar"},
    ])

    assert {:ok, [], [], [%Translation{} = t]} = parsed
    assert t.references == [{"foo.ex", 1},
                            {"bar.ex", 2},
                            {"with spaces.ex", 3},
                            {"baz.ex", 3}]
  end

  test "top-of-the-file comments are extracted correctly" do
    parsed = Parser.parse([
      {:comment, 1, "# Top of the file"},
      {:comment, 1, "## Top of the file with two hashes"},
      {:msgid, 1}, {:str, 1, ""},
      {:msgstr, 1},
        {:str, 1, "Language: en_US\n"},
    ])

    assert {
      :ok,
      ["# Top of the file", "## Top of the file with two hashes"],
      ["Language: en_US\n"],
      []
    } = parsed
  end

  test "msgctxt is parsed correctly but ignored" do
    parsed = Parser.parse([
      {:msgctxt, 1}, {:str, 1, "my_"}, {:str, 1, "context"},
      {:msgid, 2}, {:str, 2, "my_msgid"},
      {:msgstr, 3}, {:str, 3, "my_msgstr"},
    ])

    assert {:ok, [], [], [%Translation{} = translation]} = parsed
    assert translation.msgid == ["my_msgid"]
    assert translation.msgstr == ["my_msgstr"]

    # Badly placed msgctxt still causes a syntax error
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "my_msgid"},
      {:msgctxt, 2}, {:str, 2, "my_context"},
      {:msgstr, 3}, {:str, 3, "my_msgstr"},
    ])

    assert parsed == {:error, 2, "syntax error before: msgctxt"}
  end

  test "tokens are printed as Elixir terms, not Erlang terms" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, ""},
      {:comment, 1, "# comment"},
    ])

    assert {:error, _line, msg} = parsed
    assert msg == "syntax error before: \"# comment\""
  end
end
