defmodule Gettext.FuzzyTest do
  use ExUnit.Case, async: true

  alias Gettext.Fuzzy
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  test "matcher/1" do
    assert Fuzzy.matcher(0.5).("foo", "foo") == {:match, 1.0}
    assert Fuzzy.matcher(0.5).("foo", "bar") == :nomatch
    assert Fuzzy.matcher(0.0).("foo", "bar") == {:match, 0.0}
  end

  test "jaro_distance/2" do
    assert Fuzzy.jaro_distance("foo", {"foo", "bar"}) == 1.0
    assert Fuzzy.jaro_distance({"foo", "bar"}, "foo") == 1.0
    assert Fuzzy.jaro_distance("foo", "foos") > 0.0
    assert Fuzzy.jaro_distance({"foo", ""}, {"bar", ""}) == 0.0
  end

  describe "merge/2" do
    test "two translations" do
      t1 = %Translation{msgid: "foo"}
      t2 = %Translation{msgid: "foos", msgstr: "bar"}

      assert %Translation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgstr == "bar"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a translation and a plural translation" do
      t1 = %Translation{msgid: "foo"}
      t2 = %PluralTranslation{msgid: "foos", msgid_plural: "bar", msgstr: %{0 => "a", 1 => "b"}}

      assert %Translation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgstr == "a"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a plural translation and a translation" do
      t1 = %PluralTranslation{msgid: "foos", msgid_plural: "bar", msgstr: %{0 => "", 1 => ""}}
      t2 = %Translation{msgid: "foo", msgstr: "bar"}

      assert %PluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foos"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "bar", 1 => "bar"}
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "two plural translations" do
      t1 = %PluralTranslation{msgid: "foos", msgid_plural: "bar"}
      t2 = %PluralTranslation{msgid: "foo", msgid_plural: "baz", msgstr: %{0 => "a", 1 => "b"}}

      assert %PluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foos"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "a", 1 => "b"}
      assert MapSet.member?(t.flags, "fuzzy")
    end
  end
end
