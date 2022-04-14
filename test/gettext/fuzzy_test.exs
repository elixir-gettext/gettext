defmodule Gettext.FuzzyTest do
  use ExUnit.Case, async: true

  alias Gettext.Fuzzy
  alias Expo.Message

  test "matcher/1" do
    assert Fuzzy.matcher(0.5).({nil, "foo"}, {nil, "foo"}) == {:match, 1.0}
    assert Fuzzy.matcher(0.5).({nil, "foo"}, {nil, "bar"}) == :nomatch
    assert Fuzzy.matcher(0.0).({nil, "foo"}, {nil, "bar"}) == {:match, 0.0}
  end

  describe "jaro_distance/2" do
    test "compares the distance of the msgid" do
      assert Fuzzy.jaro_distance({nil, "foo"}, {nil, "foo"}) == 1.0
      assert Fuzzy.jaro_distance({nil, "foo"}, {nil, "foos"}) > 0.0
      assert Fuzzy.jaro_distance({nil, "foo"}, {nil, "bar"}) == 0.0
    end

    test "with one translation and one plural translation, only the msgids are compared" do
      assert Fuzzy.jaro_distance({nil, "foo"}, {nil, {"foo", "bar"}}) == 1.0
      assert Fuzzy.jaro_distance({nil, {"foo", "bar"}}, {nil, "foo"}) == 1.0
    end

    test "completely ignores the msgctxt in the key when calculating the distance" do
      assert Fuzzy.jaro_distance({"a", "foo"}, {"b", "foo"}) == 1.0
      assert Fuzzy.jaro_distance({"same", "foo"}, {"same", "bar"}) == 0.0
    end
  end

  describe "merge/2" do
    test "two translations" do
      t1 = %Message.Singular{msgid: ["foo"]}
      t2 = %Message.Singular{msgid: ["foos"], msgstr: ["bar"]}

      assert %Message.Singular{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == ["foo"]
      assert t.msgstr == ["bar"]
      assert Message.has_flag?(t, "fuzzy")
    end

    test "a translation and a plural translation" do
      t1 = %Message.Singular{msgid: ["foo"]}

      t2 = %Message.Plural{
        msgid: ["foos"],
        msgid_plural: ["bar"],
        msgstr: %{0 => ["a"], 1 => ["b"]}
      }

      assert %Message.Singular{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == ["foo"]
      assert t.msgstr == ["a"]
      assert Message.has_flag?(t, "fuzzy")
    end

    test "a plural translation and a translation" do
      t1 = %Message.Plural{
        msgid: ["foos"],
        msgid_plural: ["bar"],
        msgstr: %{0 => [], 1 => []}
      }

      t2 = %Message.Singular{msgid: ["foo"], msgstr: ["bar"]}

      assert %Message.Plural{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == ["foos"]
      assert t.msgid_plural == ["bar"]
      assert t.msgstr == %{0 => ["bar"], 1 => ["bar"]}
      assert Message.has_flag?(t, "fuzzy")
    end

    test "two plural translations" do
      t1 = %Message.Plural{msgid: ["foos"], msgid_plural: ["bar"]}

      t2 = %Message.Plural{
        msgid: ["foo"],
        msgid_plural: ["baz"],
        msgstr: %{0 => ["a"], 1 => ["b"]}
      }

      assert %Message.Plural{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == ["foos"]
      assert t.msgid_plural == ["bar"]
      assert t.msgstr == %{0 => ["a"], 1 => ["b"]}
      assert Message.has_flag?(t, "fuzzy")
    end
  end
end
