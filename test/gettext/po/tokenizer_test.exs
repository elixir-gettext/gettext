defmodule Gettext.PO.TokenizerTest do
  use ExUnit.Case, async: true

  import Gettext.PO.Tokenizer, only: [tokenize: 1]

  test "keywords" do
    str = "msgid msgstr "

    assert tokenize(str) ==
             {:ok,
              [
                {:msgid, 1},
                {:msgstr, 1}
              ]}

    str = "    msgid  msgid_plural    msgstr  "

    assert tokenize(str) ==
             {:ok,
              [
                {:msgid, 1},
                {:msgid_plural, 1},
                {:msgstr, 1}
              ]}

    str = "msgctxt msgid "

    assert tokenize(str) ==
             {:ok,
              [
                {:msgctxt, 1},
                {:msgid, 1}
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

  test "unexpected tokens are printed nicely (with byte codepoints)" do
    # Just to know this, but bom is "" when inspected.
    bom = <<0xEF, 0xBB, 0xBF>>
    msg = ~s[unexpected token: "#{bom}" (codepoint U+FEFF)]
    assert tokenize(bom <> ~s(msgid "foo")) == {:error, 1, msg}

    assert tokenize("å") == {:error, 1, ~s[unexpected token: "å" (codepoint U+00E5)]}
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

    assert tokenize(str) ==
             {:ok,
              [
                {:str, 1, "foo"},
                {:str, 2, "bar with \"quotes\""},
                {:str, 3, "bong"}
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

    assert tokenize(str) ==
             {:ok,
              [
                {:msgid, 1},
                {:str, 1, "foo"},
                {:msgstr, 2},
                {:str, 2, "bar"}
              ]}
  end

  test "comments are not ignored, but tokenized" do
    str = "# Single-line comment"

    assert tokenize(str) ==
             {:ok,
              [
                {:comment, 1, "# Single-line comment"}
              ]}

    str = "\t\t  # A comment after whitespace"

    assert tokenize(str) ==
             {:ok,
              [
                {:comment, 1, "# A comment after whitespace"}
              ]}

    str = "#: Single-line reference comment"

    assert tokenize(str) ==
             {:ok,
              [
                {:comment, 1, "#: Single-line reference comment"}
              ]}

    str = "#, Flags comment"

    assert tokenize(str) ==
             {:ok,
              [
                {:comment, 1, "#, Flags comment"}
              ]}
  end

  test "multi-line comments are supported" do
    str = ~S"""
    # Multiline comment
      # with weird chåracters
      #: lib/and-refs.ex:32
    """

    assert tokenize(str) ==
             {:ok,
              [
                {:comment, 1, "# Multiline comment"},
                {:comment, 2, "# with weird chåracters"},
                {:comment, 3, "#: lib/and-refs.ex:32"}
              ]}
  end

  test "comments are tokenized correctly when between other stuff" do
    # ...even if the parser throws an error in such cases.

    str = ~S"""
    # Multiline comment with
    msgid "a string"
    # in it.
    """

    assert tokenize(str) ==
             {:ok,
              [
                {:comment, 1, "# Multiline comment with"},
                {:msgid, 2},
                {:str, 2, "a string"},
                {:comment, 3, "# in it."}
              ]}
  end

  test "plural forms in msgstr" do
    str = ~s(msgstr[0] )

    assert tokenize(str) ==
             {:ok,
              [
                {:msgstr, 1},
                {:plural_form, 1, 0}
              ]}

    str = ~s(msgstr[42] )

    assert tokenize(str) ==
             {:ok,
              [
                {:msgstr, 1},
                {:plural_form, 1, 42}
              ]}
  end

  test "the integer inside a plural form must be, well, an integer" do
    str = ~s(msgstr[foo])
    assert tokenize(str) == {:error, 1, "invalid plural form"}

    str = ~s(msgstr[] )
    assert tokenize(str) == {:error, 1, "invalid plural form"}

    str = ~s(msgstr[0 1])
    assert tokenize(str) == {:error, 1, "invalid plural form"}
  end

  test "plural forms must be followed by whitespace" do
    str = ~s(msgstr[0])
    assert tokenize(str) == {:error, 1, "missing space after 'msgstr[0]'"}
  end

  test "empty/whitespace-only strings are tokenized as empty lists of tokens" do
    assert tokenize("") == {:ok, []}
    assert tokenize("   ") == {:ok, []}
    assert tokenize("\r\n\t") == {:ok, []}
  end
end
