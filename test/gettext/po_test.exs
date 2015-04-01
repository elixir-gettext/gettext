defmodule Gettext.POTest do
  use ExUnit.Case, async: true

  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.SyntaxError

  doctest PO

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

  test "parse_string!/1: valid strings" do
    str = """
    msgid "foo"
    msgstr "bar"
    """

    assert PO.parse_string!(str) == [%Translation{msgid: "foo", msgstr: "bar"}]
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

  test "parse_file!/1: valid file contents" do
    fixture_path = Path.expand("../fixtures/valid.po", __DIR__)

    assert PO.parse_file!(fixture_path) == [
      %Translation{msgid: "hello", msgstr: "ciao"},
      %Translation{msgid: "how are you, friend?", msgstr: "come stai, amico?"},
    ]
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
    assert_raise File.Error, fn ->
      PO.parse_file!("nonexistent")
    end
  end
end
