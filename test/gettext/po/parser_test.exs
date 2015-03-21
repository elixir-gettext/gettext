defmodule Gettext.PO.ParserTest do
  use ExUnit.Case

  alias Gettext.PO.Parser
  alias Gettext.PO.Translation

  test "parse/1 with single strings" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "hello"},
      {:msgstr, 2}, {:str, 2, "ciao"}
    ])

    assert parsed == {:ok, [%Translation{msgid: "hello", msgstr: "ciao"}]}
  end

  test "parse/1 with multiple concatenated strings" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "hello"}, {:str, 1, " world"},
      {:msgstr, 2}, {:str, 2, "ciao"}, {:str, 3, " mondo"}
    ])

    assert parsed == {:ok, [
      %Translation{msgid: "hello world", msgstr: "ciao mondo"}
    ]}
  end

  test "parse/1 with multiple translations" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "hello"},
      {:msgstr, 2}, {:str, 2, "ciao"},
      {:msgid, 3}, {:str, 3, "word"},
      {:msgstr, 4}, {:str, 4, "parola"},
    ])

    assert parsed == {:ok, [
      %Translation{msgid: "hello", msgstr: "ciao"},
      %Translation{msgid: "word", msgstr: "parola"},
    ]}
  end

  test "parse/1 with unicode characters in the strings" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "føø"},
      {:msgstr, 2}, {:str, 2, "bårπ"},
    ])

    assert parsed == {:ok, [%Translation{msgid: "føø", msgstr: "bårπ"}]}
  end

  test "syntax error when there is no 'msgid'" do
    parsed = Parser.parse [{:msgstr, 1}, {:str, 1, "foo"}]
    assert {:error, 1, _} = parsed

    parsed = Parser.parse [{:str, 1, "foo"}]
    assert {:error, 1, _} = parsed
  end
end
