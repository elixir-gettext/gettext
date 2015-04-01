defmodule Gettext.POTest do
  use ExUnit.Case, async: true

  alias Gettext.PO
  alias Gettext.PO.Translation

  test "parse_string/1: valid string" do
    str = """
    msgid "hello there"
    msgstr "ciao"

       msgid "indenting and " "strings"
      msgstr "indentazione " "e stringhe"
    """

    assert PO.parse_string(str) == {:ok, [
      %Translation{msgid: "hello there", msgstr: "ciao"},
      %Translation{msgid: "indenting and strings", msgstr: "indentazione e stringhe"},
    ]}
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

  test "parse_file/1: valid file contents" do
    fixture_path = Path.expand("../fixtures/valid.po", __DIR__)

    assert PO.parse_file(fixture_path) == {:ok, [
      %Translation{msgid: "hello", msgstr: "ciao"},
      %Translation{msgid: "how are you, friend?", msgstr: "come stai, amico?"},
    ]}
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
end
