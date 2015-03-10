defmodule Gettext.PO.TokenizerTest do
  use ExUnit.Case, async: true

  import Gettext.PO.Tokenizer, only: [tokenize: 1]
  alias Gettext.PO.SyntaxError
  alias Gettext.PO.TokenMissingError

  test "keywords" do
    str = "msgid msgstr "
    assert tokenize(str) == [
      {:keyword, 1, :msgid},
      {:keyword, 1, :msgstr},
    ]

    str = "    msgid      msgstr  "
    assert tokenize(str) == [
      {:keyword, 1, :msgid},
      {:keyword, 1, :msgstr},
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
      {:keyword, 1, :msgid},
      {:string, 1, "foo"},
      {:keyword, 2, :msgstr},
      {:string, 2, "bar"},
    ]
  end
end
