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

    test "with one message and one plural message, only the msgids are compared" do
      assert Fuzzy.jaro_distance({nil, "foo"}, {nil, {"foo", "bar"}}) == 1.0
      assert Fuzzy.jaro_distance({nil, {"foo", "bar"}}, {nil, "foo"}) == 1.0
    end

    test "completely ignores the msgctxt in the key when calculating the distance" do
      assert Fuzzy.jaro_distance({"a", "foo"}, {"b", "foo"}) == 1.0
      assert Fuzzy.jaro_distance({"same", "foo"}, {"same", "bar"}) == 0.0
    end
  end

  describe "merge/2" do
    test "two messages" do
      message_1 = %Message.Singular{msgid: ["foo"]}
      message_2 = %Message.Singular{msgid: ["foos"], msgstr: ["bar"]}

      assert %Message.Singular{} = message = Fuzzy.merge(message_1, message_2)

      assert message.msgid == ["foo"]
      assert message.msgstr == ["bar"]
      assert Message.has_flag?(message, "fuzzy")
    end

    test "a message and a plural message" do
      message_1 = %Message.Singular{msgid: ["foo"]}

      message_2 = %Message.Plural{
        msgid: ["foos"],
        msgid_plural: ["bar"],
        msgstr: %{0 => ["a"], 1 => ["b"]}
      }

      assert %Message.Singular{} = message = Fuzzy.merge(message_1, message_2)

      assert message.msgid == ["foo"]
      assert message.msgstr == ["a"]
      assert Message.has_flag?(message, "fuzzy")
    end

    test "a plural message and a message" do
      message_1 = %Message.Plural{
        msgid: ["foos"],
        msgid_plural: ["bar"],
        msgstr: %{0 => [], 1 => []}
      }

      message_2 = %Message.Singular{msgid: ["foo"], msgstr: ["bar"]}

      assert %Message.Plural{} = message = Fuzzy.merge(message_1, message_2)

      assert message.msgid == ["foos"]
      assert message.msgid_plural == ["bar"]
      assert message.msgstr == %{0 => ["bar"], 1 => ["bar"]}
      assert Message.has_flag?(message, "fuzzy")
    end

    test "two plural messages" do
      message_1 = %Message.Plural{msgid: ["foos"], msgid_plural: ["bar"]}

      message_2 = %Message.Plural{
        msgid: ["foo"],
        msgid_plural: ["baz"],
        msgstr: %{0 => ["a"], 1 => ["b"]}
      }

      assert %Message.Plural{} = message = Fuzzy.merge(message_1, message_2)

      assert message.msgid == ["foos"]
      assert message.msgid_plural == ["bar"]
      assert message.msgstr == %{0 => ["a"], 1 => ["b"]}
      assert Message.has_flag?(message, "fuzzy")
    end
  end
end
