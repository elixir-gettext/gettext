defmodule Gettext.PO.TokenizerTest do
  use ExUnit.Case, async: true

  import Gettext.PO.Tokenizer, only: [tokenize: 1]
  alias Gettext.PO.SyntaxError
  alias Gettext.PO.TokenMissingError

  test "keywords" do
    str = "msgid msgstr "
    assert tokenize(str) == [
      {:msgid, 1},
      {:msgstr, 1},
    ]

    str = "    msgid      msgstr  "
    assert tokenize(str) == [
      {:msgid, 1},
      {:msgstr, 1},
    ]
  end

  test "keywords must be followed by a space" do
    str = ~s(msgid"foo")
    msg = "invalid syntax on line 1: no space after 'msgid'"
    assert_raise SyntaxError, msg, fn -> tokenize(str) end

    str = ~s(msgstr"foo")
    msg = "invalid syntax on line 1: no space after 'msgstr'"
    assert_raise SyntaxError, msg, fn -> tokenize(str) end
  end

  test "single simple string" do
    str = ~s("foo bar")
    assert tokenize(str) == [{:string, 1, "foo bar"}]
  end

  test "escape characters in strings" do
    str = ~S("foo,\nbar\tbaz\\")
    assert tokenize(str) == [{:string, 1, "foo,\nbar\tbaz\\"}]

    str = ~S("fo\ø")
    msg = "invalid syntax on line 1: unsupported escape code"
    assert_raise SyntaxError, msg, fn -> tokenize(str) end

    str = ~S("\ foo")
    msg = "invalid syntax on line 1: unsupported escape code"
    assert_raise SyntaxError, msg, fn -> tokenize(str) end
  end

  test "strings on multiple lines" do
    str = ~S"""
    "foo"
      "bar with \"quotes\""
          "bong"
    """

    assert tokenize(str) == [
      {:string, 1, "foo"},
      {:string, 2, "bar with \"quotes\""},
      {:string, 3, "bong"},
    ]
  end

  test "no newlines are allowed in strings" do
    str = ~S"""
    "foo
    bar"
    """

    msg = "invalid syntax on line 1: newline in string"
    assert_raise SyntaxError, msg, fn -> tokenize(str) end
  end

  test "strings must have a terminator" do
    str = ~s("foo)
    msg = ~s(missing token " on line 1)
    assert_raise TokenMissingError, msg, fn -> tokenize(str) end
  end

  test "tokens know on what line they are" do
    str = ~S"""
    msgid "foo"
    msgstr "bar"
    """

    assert tokenize(str) == [
      {:msgid, 1},
      {:string, 1, "foo"},
      {:msgstr, 2},
      {:string, 2, "bar"},
    ]
  end

  test "single-line comments are ignored" do
    str = "# Single-line comment"
    assert tokenize(str) == []

    str = "#; Single-line non-whitespace comment"
    assert tokenize(str) == []

    str = "\t\t  # A comment"
    assert tokenize(str) == []
  end

  test "multi-line comments are ignored" do
    str = ~S"""
    # Multiline comment
      #, badly indented,
      #: with weird chåracters
    """
    assert tokenize(str) == []

    str = ~S"""
    # Multiline comment with
    msgid "a string"
    # in it.
    """
    assert tokenize(str) == [
      {:msgid, 2},
      {:string, 2, "a string"},
    ]
  end
end
