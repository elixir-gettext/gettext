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

  test "parse/1 with a pluralised string" do
    parsed = Parser.parse([
      {:msgid, 1}, {:str, 1, "foo"},
      {:msgid_plural, 1}, {:str, 1, "foos"},
      {:msgstr, 1}, {:plural_form, 1, 0}, {:str, 1, "bar"},
      {:msgstr, 1}, {:plural_form, 1, 1}, {:str, 1, "bars"},
      {:msgstr, 1}, {:plural_form, 1, 2}, {:str, 1, "barres"},
    ])

    assert parsed == {:ok, [%Translation{
      msgid: "foo",
      msgid_plural: "foos",
      msgstr: %{
        0 => "bar",
        1 => "bars",
        2 => "barres",
      },
    }]}
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

    assert parsed == {:error, 1, "syntax error before: <<\"bar\">>"}
  end

  test "'msgid_plural' must come after 'msgid'" do
    parsed = Parser.parse([{:msgid_plural, 1}])
    assert parsed == {:error, 1, "syntax error before: msgid_plural"}
  end
end
