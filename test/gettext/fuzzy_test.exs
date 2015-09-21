defmodule Gettext.FuzzyTest do
  use ExUnit.Case, async: true

  alias Gettext.Fuzzy
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  test "jaro_distance/2" do
    assert Fuzzy.jaro_distance("foo", {"foo", "bar"}) == 1.0
    assert Fuzzy.jaro_distance({"foo", "bar"}, "foo") == 1.0
    assert Fuzzy.jaro_distance("foo", "foos") > 0.0
    assert Fuzzy.jaro_distance({"foo", ""}, {"bar", ""}) == 0.0
  end

  test "merge/2: two translations" do
    assert %Translation{} = t = Fuzzy.merge(
      %Translation{msgid: "foo"},
      %Translation{msgid: "foos", msgstr: "bar"}
    )
    assert t.msgid == "foo"
    assert t.msgstr == "bar"
    assert MapSet.member?(t.flags, "fuzzy")
  end

  test "merge/2: a translation and a plural translation" do
    assert %Translation{} = t = Fuzzy.merge(
      %Translation{msgid: "foo"},
      %PluralTranslation{msgid: "foos", msgid_plural: "bar", msgstr: %{0 => "a", 1 => "b"}}
    )
    assert t.msgid == "foo"
    assert t.msgstr == "a"
    assert MapSet.member?(t.flags, "fuzzy")
  end

  test "merge/2: a plural translation and a translation" do
    assert %PluralTranslation{} = t = Fuzzy.merge(
      %PluralTranslation{msgid: "foos", msgid_plural: "bar", msgstr: %{0 => "", 1 => ""}},
      %Translation{msgid: "foo", msgstr: "bar"}
    )
    assert t.msgid == "foos"
    assert t.msgid_plural == "bar"
    assert t.msgstr == %{0 => "bar", 1 => "bar"}
    assert MapSet.member?(t.flags, "fuzzy")
  end

  test "merge/2: two plural translations" do
    assert %PluralTranslation{} = t = Fuzzy.merge(
      %PluralTranslation{msgid: "foos", msgid_plural: "bar"},
      %PluralTranslation{msgid: "foo", msgid_plural: "baz", msgstr: %{0 => "a", 1 => "b"}}
    )
    assert t.msgid == "foos"
    assert t.msgid_plural == "bar"
    assert t.msgstr == %{0 => "a", 1 => "b"}
    assert MapSet.member?(t.flags, "fuzzy")
  end
end
