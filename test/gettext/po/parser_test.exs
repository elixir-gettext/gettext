defmodule Gettext.PO.ParserTest do
  use ExUnit.Case

  alias Gettext.PO.Parser
  alias Gettext.PO.Parser.Translation
  alias Gettext.PO.SyntaxError

  test "parse/1 with single strings" do
    parsed = Parser.parse([
      {:msgid, 1}, {:string, 1, "hello"},
      {:msgstr, 2}, {:string, 2, "ciao"}
    ])

    assert parsed == [%Translation{msgid: "hello", msgstr: "ciao"}]
  end

  test "parse/1 with multiple concatenated strings" do
    parsed = Parser.parse([
      {:msgid, 1}, {:string, 1, "hello"}, {:string, 1, " world"},
      {:msgstr, 2}, {:string, 2, "ciao"}, {:string, 3, " mondo"}
    ])

    assert parsed == [%Translation{msgid: "hello world", msgstr: "ciao mondo"}]
  end

  test "parse/1 with multiple translations" do
    parsed = Parser.parse([
      {:msgid, 1}, {:string, 1, "hello"},
      {:msgstr, 2}, {:string, 2, "ciao"},
      {:msgid, 3}, {:string, 3, "word"},
      {:msgstr, 4}, {:string, 4, "parola"},
    ])

    assert parsed == [
      %Translation{msgid: "hello", msgstr: "ciao"},
      %Translation{msgid: "word", msgstr: "parola"},
    ]
  end

  test "parse/1 with unicode characters in the strings" do
    parsed = Parser.parse([
      {:msgid, 1}, {:string, 1, "føø"},
      {:msgstr, 2}, {:string, 2, "bårπ"},
    ])

    assert parsed == [%Translation{msgid: "føø", msgstr: "bårπ"}]
  end

  test "syntax error when there is no 'msgid'" do
    assert_raise SyntaxError, fn ->
      Parser.parse [{:msgstr, 1}, {:string, 1, "foo"}]
    end

    assert_raise SyntaxError, fn ->
      Parser.parse [{:string, 1, "foo"}]
    end
  end
end
