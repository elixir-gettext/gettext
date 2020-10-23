defmodule Gettext.InterpolationTest do
  use ExUnit.Case, async: true
  doctest Gettext.Interpolation
  alias Gettext.Interpolation

  describe "interpolate/2" do
    test "with bindings with atom keys" do
      interpolatable = Interpolation.to_interpolatable("%{a} %{b} %{c}")

      assert Interpolation.interpolate(interpolatable, %{a: 1, b: :two, c: "thr ee"}) ==
               {:ok, "1 two thr ee"}

      assert Interpolation.interpolate(interpolatable, %{a: "a"}) ==
               {:missing_bindings, "a %{b} %{c}", [:b, :c]}

      interpolatable = Interpolation.to_interpolatable("%{a} %{a} %{a}")

      assert Interpolation.interpolate(interpolatable, %{a: "foo"}) == {:ok, "foo foo foo"}

      assert Interpolation.interpolate(interpolatable, %{b: "bar"}) ==
               {:missing_bindings, "%{a} %{a} %{a}", [:a]}
    end

    test "with bindings with string keys" do
      interpolatable = Interpolation.to_interpolatable("%{a} %{b} %{c}", mode: :string_keys)

      assert Interpolation.interpolate(interpolatable, %{"a" => 1, "b" => :two, "c" => "thr ee"},
               mode: :string_keys
             ) == {:ok, "1 two thr ee"}

      assert Interpolation.interpolate(interpolatable, %{"a" => "a"}, mode: :string_keys) ==
               {:missing_bindings, "a %{b} %{c}", ["b", "c"]}

      interpolatable = Interpolation.to_interpolatable("%{a} %{a} %{a}", mode: :string_keys)

      assert Interpolation.interpolate(interpolatable, %{"a" => "foo"}, mode: :string_keys) ==
               {:ok, "foo foo foo"}

      assert Interpolation.interpolate(interpolatable, %{"b" => "bar"}, mode: :string_keys) ==
               {:missing_bindings, "%{a} %{a} %{a}", ["a"]}
    end
  end

  describe "to_interpolatable/1" do
    test "expecting atom keys" do
      assert Interpolation.to_interpolatable("Hello %{name}") == ["Hello ", :name]
      assert Interpolation.to_interpolatable("%{solo}") == [:solo]
      assert Interpolation.to_interpolatable("%{foo}%{bar} %{baz}") == [:foo, :bar, " ", :baz]

      assert Interpolation.to_interpolatable("%{Your name} is cool!") == [
               :"Your name",
               " is cool!"
             ]

      assert Interpolation.to_interpolatable("foo %{} bar") == ["foo %{} bar"]
      assert Interpolation.to_interpolatable("%{") == ["%{"]
      assert Interpolation.to_interpolatable("abrupt ending %{") == ["abrupt ending %{"]

      assert Interpolation.to_interpolatable("incomplete %{ and then some") ==
               ["incomplete %{ and then some"]

      assert Interpolation.to_interpolatable("first empty %{} then %{ incomplete") ==
               ["first empty %{} then %{ incomplete"]

      assert Interpolation.to_interpolatable("") == []
    end

    test "expecting string keys" do
      assert Interpolation.to_interpolatable("Hello %{name}", mode: :string_keys) == [
               "Hello ",
               "%{name}"
             ]

      assert Interpolation.to_interpolatable("%{solo}", mode: :string_keys) == ["%{solo}"]

      assert Interpolation.to_interpolatable("%{foo}%{bar} %{baz}", mode: :string_keys) == [
               "%{foo}",
               "%{bar}",
               " ",
               "%{baz}"
             ]

      assert Interpolation.to_interpolatable("%{Your name} is cool!", mode: :string_keys) == [
               "%{Your name}",
               " is cool!"
             ]

      assert Interpolation.to_interpolatable("foo %{} bar", mode: :string_keys) == ["foo %{} bar"]
      assert Interpolation.to_interpolatable("%{", mode: :string_keys) == ["%{"]

      assert Interpolation.to_interpolatable("abrupt ending %{", mode: :string_keys) == [
               "abrupt ending %{"
             ]

      assert Interpolation.to_interpolatable("incomplete %{ and then some", mode: :string_keys) ==
               ["incomplete %{ and then some"]

      assert Interpolation.to_interpolatable("first empty %{} then %{ incomplete",
               mode: :string_keys
             ) ==
               ["first empty %{} then %{ incomplete"]

      assert Interpolation.to_interpolatable("", mode: :string_keys) == []
    end
  end

  if :erlang.system_info(:otp_release) >= '20' do
    test "to_interpolatable/1 with Unicode" do
      assert Interpolation.to_interpolatable("%{Héllø} there") ==
               [String.to_atom("Héllø"), " there"]
    end
  end

  test "keys/1" do
    # With a string as its argument
    assert Interpolation.keys("Hello %{name}") == [:name]
    assert Interpolation.keys("It's %{time} here in %{state}") == [:time, :state]
    assert Interpolation.keys("Hi there %{your name}") == [:"your name"]
    assert Interpolation.keys("Hello %{name} in %{state} goodbye %{name}") == [:name, :state]

    # With a list of segments as its argument
    assert Interpolation.keys(["Hello ", :name, " it's ", :time, " goodbye ", :name]) ==
             [:name, :time]
  end
end
