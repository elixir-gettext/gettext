defmodule Gettext.MergerTest do
  use ExUnit.Case, async: true

  alias Gettext.Merger
  alias Gettext.PO
  alias Gettext.PO.Translation

  @opts fuzzy: true, fuzzy_threshold: 0.8
  @pot_path "../../tmp/" |> Path.expand(__DIR__) |> Path.relative_to_cwd()

  test "merge/2: headers from the old file are kept" do
    old_po = %PO{headers: [~S(Language: it\n)]}
    new_pot = %PO{headers: ["foo"]}

    assert Merger.merge(old_po, new_pot, @opts).headers == old_po.headers
  end

  test "merge/2: obsolete translations are discarded (even the manually entered ones)" do
    old_po = %PO{
      translations: [
        %Translation{msgid: "obs_auto", msgstr: "foo", flags: MapSet.new(["elixir-format"])},
        %Translation{msgid: "obs_manual", msgstr: "foo"},
        %Translation{msgid: "tomerge", msgstr: "foo"}
      ]
    }

    new_pot = %PO{translations: [%Translation{msgid: "tomerge", msgstr: ""}]}

    assert %PO{translations: [t]} = Merger.merge(old_po, new_pot, @opts)
    assert %Translation{msgid: "tomerge", msgstr: "foo"} = t
  end

  test "merge/2: when translations match, the msgstr of the old one is preserved" do
    # Note that the msgstr of the new one must be empty as the new one comes
    # from a POT file.

    old_po = %PO{translations: [%Translation{msgid: "foo", msgstr: "bar"}]}
    new_pot = %PO{translations: [%Translation{msgid: "foo", msgstr: ""}]}

    assert %PO{translations: [t]} = Merger.merge(old_po, new_pot, @opts)
    assert t.msgstr == "bar"
  end

  test "merge/2: when translations match, existing translator comments are preserved" do
    # Note that the new translation should not have any translator comments
    # (comes from a POT file).

    old_po = %PO{translations: [%Translation{msgid: "foo", comments: ["# existing comment"]}]}
    new_pot = %PO{translations: [%Translation{msgid: "foo", comments: ["# new comment"]}]}

    assert %PO{translations: [t]} = Merger.merge(old_po, new_pot, @opts)
    assert t.comments == ["# existing comment"]
  end

  test "merge/2: when translations match, existing extracted comments are replaced by new ones" do
    old_po = %PO{
      translations: [
        %Translation{
          msgid: "foo",
          extracted_comments: ["#. existing comment", "#. other existing comment"]
        }
      ]
    }

    new_pot = %PO{
      translations: [%Translation{msgid: "foo", extracted_comments: ["#. new comment"]}]
    }

    assert %PO{translations: [t]} = Merger.merge(old_po, new_pot, @opts)
    assert t.extracted_comments == ["#. new comment"]
  end

  test "merge/2: when translations match, existing references are replaced by new ones" do
    old_po = %PO{translations: [%Translation{msgid: "foo", references: [{"foo.ex", 1}]}]}
    new_pot = %PO{translations: [%Translation{msgid: "foo", references: [{"bar.ex", 1}]}]}

    assert %PO{translations: [t]} = Merger.merge(old_po, new_pot, @opts)
    assert t.references == [{"bar.ex", 1}]
  end

  test "merge/2: when translations match, existing flags are replaced by new ones" do
    old_po = %PO{translations: [%Translation{msgid: "foo"}]}

    new_pot = %PO{
      translations: [%Translation{msgid: "foo", flags: MapSet.new(["elixir-format"])}]
    }

    assert %PO{translations: [t]} = Merger.merge(old_po, new_pot, @opts)
    assert t.flags == MapSet.new(["elixir-format"])
  end

  test "merge/2: new translations are fuzzy matched against obsolete translations" do
    old_po = %PO{translations: [%Translation{msgid: "hello world!", msgstr: ["foo"]}]}
    new_pot = %PO{translations: [%Translation{msgid: "hello worlds!"}]}

    assert %PO{translations: [t]} = Merger.merge(old_po, new_pot, @opts)
    assert MapSet.member?(t.flags, "fuzzy")
    assert t.msgid == "hello worlds!"
    assert t.msgstr == ["foo"]
  end

  test "merge/2: exact matches have precedence over fuzzy matches" do
    old_po = %PO{
      translations: [
        %Translation{msgid: "hello world!", msgstr: ["foo"]},
        %Translation{msgid: "hello worlds!", msgstr: ["bar"]}
      ]
    }

    new_pot = %PO{translations: [%Translation{msgid: "hello world!"}]}

    # Let's check that the "hello worlds!" translation is discarded even if it's
    # a fuzzy match for "hello world!".
    assert %PO{translations: [t]} = Merger.merge(old_po, new_pot, @opts)
    refute MapSet.member?(t.flags, "fuzzy")
    assert t.msgid == "hello world!"
    assert t.msgstr == ["foo"]
  end

  test "new_po_file/2" do
    pot_path = Path.join(@pot_path, "new_po_file.pot")
    new_po_path = Path.join(@pot_path, "it/LC_MESSAGES/new_po_file.po")

    write_file(pot_path, """
    ## Stripme!
    # A comment
    msgid "foo"
    msgstr "bar"
    """)

    merged = Merger.new_po_file(new_po_path, pot_path) |> IO.iodata_to_binary()

    assert String.ends_with?(merged, ~S"""
           msgid ""
           msgstr ""
           "Language: it\n"

           # A comment
           msgid "foo"
           msgstr "bar"
           """)

    assert String.starts_with?(merged, "## `msgid`s in this file come from POT")
  end

  defp write_file(path, contents) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, contents)
  end
end
