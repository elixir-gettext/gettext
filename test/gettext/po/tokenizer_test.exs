defmodule Gettext.PO.TokenizerTest do
  use ExUnit.Case, async: true

  import Gettext.PO.Tokenizer, only: [tokenize: 1]

  test "keywords" do
    str = "msgid msgstr "
    assert tokenize(str) == {:ok, [
      {:msgid, 1},
      {:msgstr, 1},
    ]}

    str = "    msgid  msgid_plural    msgstr  "
    assert tokenize(str) == {:ok, [
      {:msgid, 1},
      {:msgid_plural, 1},
      {:msgstr, 1},
    ]}
  end

  test "keywords must be followed by a space" do
    str = ~s(msgid"foo")
    assert tokenize(str) == {:error, 1, "no space after 'msgid'"}

    str = ~s(msgstr"foo")
    assert tokenize(str) == {:error, 1, "no space after 'msgstr'"}
  end

  test "unknown keywords cause a (nice) error" do
    str = ~s(msg "foo")
    assert tokenize(str) == {:error, 1, "unknown keyword 'msg'"}
  end

  test "single simple string" do
    str = ~s("foo bar")
    assert tokenize(str) == {:ok, [{:str, 1, "foo bar"}]}
  end

  test "escape characters in strings" do
    str = ~S("foo,\nbar\tbaz\\")
    assert tokenize(str) == {:ok, [{:str, 1, "foo,\nbar\tbaz\\"}]}

    str = ~S("fo\ø")
    assert tokenize(str) == {:error, 1, "unsupported escape code"}

    str = ~S("\ foo")
    assert tokenize(str) == {:error, 1, "unsupported escape code"}
  end

  test "strings on multiple lines" do
    str = ~S"""
    "foo"
      "bar with \"quotes\""
          "bong"
    """

    assert tokenize(str) == {:ok, [
      {:str, 1, "foo"},
      {:str, 2, "bar with \"quotes\""},
      {:str, 3, "bong"},
    ]}
  end

  test "no newlines are allowed in strings" do
    str = ~S"""
    "foo
    bar"
    """

    assert tokenize(str) == {:error, 1, "newline in string"}
  end

  test "strings must have a terminator" do
    str = ~s("foo)
    assert tokenize(str) == {:error, 1, ~s(missing token ")}
  end

  test "tokens know on what line they are" do
    str = ~S"""
    msgid "foo"
    msgstr "bar"
    """

    assert tokenize(str) == {:ok, [
      {:msgid, 1},
      {:str, 1, "foo"},
      {:msgstr, 2},
      {:str, 2, "bar"},
    ]}
  end

  test "single-line comments are ignored" do
    str = "# Single-line comment"
    assert tokenize(str) == {:ok, []}

    str = "#; Single-line non-whitespace comment"
    assert tokenize(str) == {:ok, []}

    str = "\t\t  # A comment"
    assert tokenize(str) == {:ok, []}
  end

  test "multi-line comments are ignored" do
    str = ~S"""
    # Multiline comment
      #, badly indented,
      #: with weird chåracters
    """
    assert tokenize(str) == {:ok, []}

    str = ~S"""
    # Multiline comment with
    msgid "a string"
    # in it.
    """
    assert tokenize(str) == {:ok, [
      {:msgid, 2},
      {:str, 2, "a string"},
    ]}
  end
end
