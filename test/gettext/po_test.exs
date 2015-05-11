defmodule Gettext.POTest do
  use ExUnit.Case, async: true

  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation
  alias Gettext.PO.SyntaxError

  doctest PO

  test "parse_string/1: valid string" do
    str = """
    msgid "hello there"
    msgstr "ciao"

       msgid "indenting and " "strings"
      msgstr "indentazione " "e stringhe"
    """

    assert PO.parse_string(str) == {:ok, %PO{headers: [], translations: [
      %Translation{msgid: "hello there", msgstr: "ciao"},
      %Translation{msgid: "indenting and strings", msgstr: "indentazione e stringhe"},
    ]}}
  end

  test "parse_string/1: invalid strings" do
    str = """
    msgid
    msgstr "foo"
    """
    assert PO.parse_string(str) == {:error, 1, "syntax error before: msgstr"}

    str = "msg"
    assert PO.parse_string(str) == {:error, 1, "unknown keyword 'msg'"}

    str = """
    msgid "foo
    bar"
    """
    assert PO.parse_string(str) == {:error, 1, "newline in string"}
  end

  test "parse_string!/1: valid strings" do
    str = """
    msgid "foo"
    msgstr "bar"
    """

    assert PO.parse_string!(str) == %PO{
      translations: [%Translation{msgid: "foo", msgstr: "bar"}],
      headers: []
    }
  end

  test "parse_string!/1: invalid strings" do
    str = "msg"
    assert_raise SyntaxError, "1: unknown keyword 'msg'", fn ->
      PO.parse_string!(str)
    end

    str = """

    msgid
    msgstr "bar"
    """
    assert_raise SyntaxError, "2: syntax error before: msgstr", fn ->
      PO.parse_string!(str)
    end
  end

  test "parse_string(!)/1: headers" do
    str = ~S"""
    msgid ""
    msgstr ""
      "Project-Id-Version: xxx\n"
      "Report-Msgid-Bugs-To: \n"
      "POT-Creation-Date: 2010-07-06 12:31-0500\n"

    msgid "foo"
    msgstr "bar"
    """

    assert {:ok, %PO{
      translations: [%Translation{msgid: "foo", msgstr: "bar"}],
      headers: [
        "Project-Id-Version: xxx",
        "Report-Msgid-Bugs-To: ",
        "POT-Creation-Date: 2010-07-06 12:31-0500",
      ]
    }} = PO.parse_string(str)
  end

  test "parse_file/1: valid file contents" do
    fixture_path = Path.expand("../fixtures/valid.po", __DIR__)

    assert PO.parse_file(fixture_path) == {:ok, %PO{headers: [], translations: [
      %Translation{msgid: "hello", msgstr: "ciao"},
      %Translation{msgid: "how are you, friend?", msgstr: "come stai, amico?"},
    ]}}
  end

  test "parse_file/1: invalid file contents" do
    fixture_path = Path.expand("../fixtures/invalid_syntax_error.po", __DIR__)
    assert PO.parse_file(fixture_path) == {:error, 4, "syntax error before: msgstr"}

    fixture_path = Path.expand("../fixtures/invalid_token_error.po", __DIR__)
    assert PO.parse_file(fixture_path) == {:error, 3, "unknown keyword 'msg'"}
  end

  test "parse_file/1: missing file" do
    assert PO.parse_file("nonexistent") == {:error, :enoent}
  end

  test "parse_file!/1: valid file contents" do
    fixture_path = Path.expand("../fixtures/valid.po", __DIR__)

    assert PO.parse_file!(fixture_path) == %PO{headers: [], translations: [
      %Translation{msgid: "hello", msgstr: "ciao"},
      %Translation{msgid: "how are you, friend?", msgstr: "come stai, amico?"},
    ]}
  end

  test "parse_file!/1: invalid file contents" do
    fixture_path = Path.expand("../fixtures/invalid_syntax_error.po", __DIR__)
    msg = "invalid_syntax_error.po:4: syntax error before: msgstr"
    assert_raise SyntaxError, msg, fn ->
      PO.parse_file!(fixture_path)
    end

    fixture_path = Path.expand("../fixtures/invalid_token_error.po", __DIR__)
    msg = "invalid_token_error.po:3: unknown keyword 'msg'"
    assert_raise SyntaxError, msg, fn ->
      PO.parse_file!(fixture_path)
    end
  end

  test "parse_file!/1: missing file" do
    msg = "could not parse nonexistent: no such file or directory"
    assert_raise File.Error, msg, fn ->
      PO.parse_file!("nonexistent")
    end
  end

  test "dump/1: single translation" do
    po = %PO{headers: [], translations: [
      %Translation{msgid: "foo", msgstr: "bar"},
    ]}

    assert PO.dump(po) == ~S"""
    msgid "foo"
    msgstr "bar"
    """
  end

  test "dump/1: single plural translation" do
    po = %PO{headers: [], translations: [%PluralTranslation{
      msgid: "one foo",
      msgid_plural: "%{count} foos",
      msgstr: %{
        0 => "one bar",
        1 => "%{count} bars"
      }
    }]}

    assert PO.dump(po) == ~S"""
    msgid "one foo"
    msgid_plural "%{count} foos"
    msgstr[0] "one bar"
    msgstr[1] "%{count} bars"
    """
  end

  test "dump/1: multiple translations" do
    po = %PO{headers: [], translations: [
      %Translation{msgid: "foo", msgstr: "bar"},
      %Translation{msgid: "baz", msgstr: "bong"},
    ]}

    assert PO.dump(po) == ~S"""
    msgid "foo"
    msgstr "bar"

    msgid "baz"
    msgstr "bong"
    """
  end

  test "dump/1: translation with comments" do
    po = %PO{headers: [], translations: [
      %Translation{
        msgid: "foo",
        msgstr: "bar",
        comments: ["# comment", "#: foo.ex:32", "# another comment"],
      }
    ]}

    assert PO.dump(po) == ~S"""
    # comment
    #: foo.ex:32
    # another comment
    msgid "foo"
    msgstr "bar"
    """
  end

  test "dump/1: headers" do
    po = %PO{translations: [], headers: [
      "Content-Type: text/plain",
      "Project-Id-Version: xxx",
    ]}

    assert PO.dump(po) == ~S"""
    msgid ""
    msgstr ""
    "Content-Type: text/plain\n"
    "Project-Id-Version: xxx\n"
    """
  end

  test "dump/1: headers and multiple (plural) translations with comments" do
    po = %PO{
      translations: [
        %Translation{
          msgid: "foo",
          msgstr: "bar",
          comments: ["# comment", "#: foo.ex:32", "# another comment"],
        },
        %PluralTranslation{
          msgid: "a foo, %{name}",
          msgid_plural: "%{count} foos, %{name}",
          msgstr: %{0 => "a bar, %{name}", 1 => "%{count} bars, %{name}"},
          comments: ["# comment 1", "# comment 2", "#: lib/ref.ex:29"],
        }
      ],
      headers: [
        "Project-Id-Version: 1",
        "Language: fooesque",
      ]
    }

    assert PO.dump(po) == ~S"""
    msgid ""
    msgstr ""
    "Project-Id-Version: 1\n"
    "Language: fooesque\n"

    # comment
    #: foo.ex:32
    # another comment
    msgid "foo"
    msgstr "bar"

    # comment 1
    # comment 2
    #: lib/ref.ex:29
    msgid "a foo, %{name}"
    msgid_plural "%{count} foos, %{name}"
    msgstr[0] "a bar, %{name}"
    msgstr[1] "%{count} bars, %{name}"
    """
  end
end
