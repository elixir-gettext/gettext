defmodule Gettext.POTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation
  alias Gettext.PO.SyntaxError

  doctest PO

  @bom <<0xEF, 0xBB, 0xBF>>

  describe "parse_string/1" do
    test "valid string" do
      str = """
      msgid "hello there"
      msgstr "ciao"

         msgid "indenting and " "strings"
        msgstr "indentazione " "e stringhe"
      """

      assert {:ok,
              %PO{
                headers: [],
                translations: [
                  %Translation{msgid: ["hello there"], msgstr: ["ciao"]},
                  %Translation{
                    msgid: ["indenting and ", "strings"],
                    msgstr: ["indentazione ", "e stringhe"]
                  }
                ]
              }} = PO.parse_string(str)
    end

    test "invalid strings" do
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

    test "BOM byte sequence at the beginning" do
      str =
        @bom <>
          """
          msgid "foo"
          msgstr "bar"
          """

      output =
        capture_io(:stderr, fn ->
          assert {:ok, %Gettext.PO{}} = PO.parse_string(str)
        end)

      assert output =~ "nofile: warning: the string being parsed starts with a BOM byte sequence"
    end
  end

  describe "parse_string!/1" do
    test "valid strings" do
      str = """
      msgid "foo"
      msgstr "bar"
      """

      assert %PO{
               translations: [%Translation{msgid: ["foo"], msgstr: ["bar"]}],
               headers: []
             } = PO.parse_string!(str)
    end

    test "invalid strings" do
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

    assert {:ok,
            %PO{
              translations: [%Translation{msgid: ["foo"], msgstr: ["bar"]}],
              headers: [
                "",
                "Project-Id-Version: xxx\n",
                "Report-Msgid-Bugs-To: \n",
                "POT-Creation-Date: 2010-07-06 12:31-0500\n"
              ]
            }} = PO.parse_string(str)
  end

  describe "parse_file/1" do
    test "valid file contents" do
      fixture_path = Path.expand("../fixtures/valid.po", __DIR__)

      assert {:ok,
              %PO{
                headers: [],
                translations: [
                  %Translation{msgid: ["hello"], msgstr: ["ciao"]},
                  %Translation{
                    msgid: ["how are you,", " friend?"],
                    msgstr: ["come stai,", " amico?"]
                  }
                ]
              }} = PO.parse_file(fixture_path)
    end

    test "invalid file contents" do
      fixture_path = Path.expand("../fixtures/invalid_syntax_error.po", __DIR__)
      assert PO.parse_file(fixture_path) == {:error, 4, "syntax error before: msgstr"}

      fixture_path = Path.expand("../fixtures/invalid_token_error.po", __DIR__)
      assert PO.parse_file(fixture_path) == {:error, 3, "unknown keyword 'msg'"}
    end

    test "missing file" do
      assert PO.parse_file("nonexistent") == {:error, :enoent}
    end

    test "file starting with a BOM byte sequence" do
      fixture_path = Path.expand("../fixtures/bom.po", __DIR__)

      output =
        capture_io(:stderr, fn ->
          assert {:ok, po} = PO.parse_file(fixture_path)
          assert [%Translation{msgid: ["foo"], msgstr: ["bar"]}] = po.translations
        end)

      assert output =~ "#{fixture_path}: warning: the file being parsed starts with a BOM"
      refute output =~ "nofile: warning: the string being parsed"
    end
  end

  describe "parse_file!/1" do
    test "populates the :file field with the path of the parsed file" do
      fixture_path = Path.expand("../fixtures/valid.po", __DIR__)
      assert %PO{file: ^fixture_path} = PO.parse_file!(fixture_path)
    end

    test "valid file contents" do
      fixture_path = Path.expand("../fixtures/valid.po", __DIR__)

      assert %PO{
               headers: [],
               translations: [
                 %Translation{msgid: ["hello"], msgstr: ["ciao"]},
                 %Translation{
                   msgid: ["how are you,", " friend?"],
                   msgstr: ["come stai,", " amico?"]
                 }
               ]
             } = PO.parse_file!(fixture_path)
    end

    test "invalid file contents" do
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

    test "missing file" do
      # We're using a regex because we want optional double quotes around the file
      # path: the error message (for File.read!/1) in Elixir v1.2 doesn't have
      # them, but it does in v1.3.
      msg = ~r/could not parse "?nonexistent"?: no such file or directory/

      assert_raise File.Error, msg, fn ->
        PO.parse_file!("nonexistent")
      end
    end

    test "empty files don't cause parsing errors" do
      fixture_path = Path.expand("../fixtures/empty.po", __DIR__)
      assert %PO{translations: [], headers: []} = PO.parse_file!(fixture_path)
    end
  end

  describe "dump/1" do
    test "single translation" do
      po = %PO{
        headers: [],
        translations: [
          %Translation{msgid: ["foo"], msgstr: ["bar"]}
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             msgid "foo"
             msgstr "bar"
             """
    end

    test "single plural translation" do
      po = %PO{
        headers: [],
        translations: [
          %PluralTranslation{
            msgid: ["one foo"],
            msgid_plural: ["%{count} foos"],
            msgstr: %{
              0 => ["one bar"],
              1 => ["%{count} bars"]
            }
          }
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             msgid "one foo"
             msgid_plural "%{count} foos"
             msgstr[0] "one bar"
             msgstr[1] "%{count} bars"
             """
    end

    test "multiple translations" do
      po = %PO{
        headers: [],
        translations: [
          %Translation{msgid: ["foo"], msgstr: ["bar"]},
          %Translation{msgid: ["baz"], msgstr: ["bong"]}
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             msgid "foo"
             msgstr "bar"

             msgid "baz"
             msgstr "bong"
             """
    end

    test "translation with comments" do
      po = %PO{
        headers: [],
        translations: [
          %Translation{
            msgid: ["foo"],
            msgstr: ["bar"],
            comments: ["# comment", "# another comment"]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             # comment
             # another comment
             msgid "foo"
             msgstr "bar"
             """
    end

    test "translation with extracted comments" do
      po = %PO{
        headers: [],
        translations: [
          %Translation{
            msgid: ["foo"],
            msgstr: ["bar"],
            extracted_comments: ["#. some comment", "#. another comment"]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             #. some comment
             #. another comment
             msgid "foo"
             msgstr "bar"
             """
    end

    test "references" do
      po = %PO{
        translations: [
          %Translation{
            msgid: ["foo"],
            msgstr: ["bar"],
            references: [{"foo.ex", 1}, {"lib/bar.ex", 2}]
          },
          %PluralTranslation{
            msgid: ["foo"],
            msgid_plural: ["foos"],
            msgstr: %{0 => [""], 1 => [""]},
            references: [{"lib/with spaces.ex", 1}, {"lib/with other spaces.ex", 2}]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             #: foo.ex:1 lib/bar.ex:2
             msgid "foo"
             msgstr "bar"

             #: lib/with spaces.ex:1 lib/with other spaces.ex:2
             msgid "foo"
             msgid_plural "foos"
             msgstr[0] ""
             msgstr[1] ""
             """
    end

    test "references can be not dumped through configuration" do
      po = %PO{
        translations: [
          %Translation{
            msgid: ["foo"],
            msgstr: ["bar"],
            comments: ["# comment"],
            references: [{"foo.ex", 1}, {"lib/bar.ex", 2}]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po, write_reference_comments: false)) == ~S"""
             # comment
             msgid "foo"
             msgstr "bar"
             """
    end

    test "references are wrapped" do
      po = %PO{
        translations: [
          %Translation{
            msgid: ["foo"],
            msgstr: ["bar"],
            references: [
              {String.duplicate("a", 50) <> ".ex", 1},
              {String.duplicate("b", 50) <> ".ex", 2}
            ]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             #: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.ex:1
             #: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.ex:2
             msgid "foo"
             msgstr "bar"
             """
    end

    test "flags" do
      po = %PO{
        translations: [
          %Translation{
            flags: MapSet.new(~w(bar baz foo)),
            comments: ["# other comment"],
            msgid: ["foo"],
            msgstr: ["bar"]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             # other comment
             #, bar, baz, foo
             msgid "foo"
             msgstr "bar"
             """
    end

    test "headers" do
      po = %PO{
        translations: [],
        headers: [
          "Content-Type: text/plain\n",
          "Project-Id-Version: xxx\n"
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             msgid ""
             msgstr ""
             "Content-Type: text/plain\n"
             "Project-Id-Version: xxx\n"
             """
    end

    test "multiple strings" do
      po = %PO{
        headers: [],
        translations: [
          %Translation{msgid: ["", "foo\n", "morefoo\n"], msgstr: ["bar", "baz\n", "bang"]},
          %PluralTranslation{
            msgid: ["a", "b"],
            msgid_plural: ["as", "bs"],
            msgstr: %{
              0 => ["c", "d"],
              1 => ["e", "f"]
            }
          }
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             msgid ""
             "foo\n"
             "morefoo\n"
             msgstr "bar"
             "baz\n"
             "bang"

             msgid "a"
             "b"
             msgid_plural "as"
             "bs"
             msgstr[0] "c"
             "d"
             msgstr[1] "e"
             "f"
             """
    end

    test "headers and multiple (plural) translations with comments" do
      po = %PO{
        translations: [
          %Translation{
            msgid: ["foo"],
            msgstr: ["bar"],
            comments: ["# comment", "# another comment"]
          },
          %PluralTranslation{
            msgid: ["a foo, %{name}"],
            msgid_plural: ["%{count} foos, %{name}"],
            msgstr: %{0 => ["a bar, %{name}"], 1 => ["%{count} bars, %{name}"]},
            comments: ["# comment 1", "# comment 2"]
          }
        ],
        headers: [
          "Project-Id-Version: 1\n",
          "Language: fooesque\n"
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             msgid ""
             msgstr ""
             "Project-Id-Version: 1\n"
             "Language: fooesque\n"

             # comment
             # another comment
             msgid "foo"
             msgstr "bar"

             # comment 1
             # comment 2
             msgid "a foo, %{name}"
             msgid_plural "%{count} foos, %{name}"
             msgstr[0] "a bar, %{name}"
             msgstr[1] "%{count} bars, %{name}"
             """
    end

    test "escaped characters in msgid/msgstr" do
      po = %PO{
        headers: [],
        translations: [
          %Translation{msgid: [~s("quotes")], msgstr: [~s(foo "bar" baz)]},
          %Translation{msgid: [~s(new\nlines\r)], msgstr: [~s(and\ttabs)]}
        ]
      }

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             msgid "\"quotes\""
             msgstr "foo \"bar\" baz"

             msgid "new\nlines\r"
             msgstr "and\ttabs"
             """
    end

    test "double quotes in headers are escaped" do
      po = %PO{headers: [~s(Foo: "bar"\n)]}

      assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
             msgid ""
             msgstr ""
             "Foo: \"bar\"\n"
             """
    end
  end

  test "parsing and re-dumping: dangling comments are ignored and not dumped back" do
    str = """
    # comment
    msgid "foo"
    msgstr "bar"

    # dangling comment
    """

    assert str |> PO.parse_string!() |> PO.dump() |> IO.iodata_to_binary() == """
           # comment
           msgid "foo"
           msgstr "bar"
           """
  end

  # Individual testing of the `dump(parse(po)) == po` process for different PO
  # editors.
  for file <- Path.wildcard("test/fixtures/po_editors/*.po") do
    editor = Path.basename(file, ".ex")

    test "parsing and dumping gives back the original file (editor: #{editor})" do
      file = unquote(file)
      parsed_and_dumped = file |> PO.parse_file!() |> PO.dump() |> IO.iodata_to_binary()
      assert parsed_and_dumped == File.read!(file)
    end
  end
end
