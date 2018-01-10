defmodule Gettext.InterpolationTest do
  use ExUnit.Case, async: true
  doctest Gettext.Interpolation
  alias Gettext.Interpolation

  test "interpolate/2" do
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

  test "to_interpolatable/1" do
    assert Interpolation.to_interpolatable("Hello %{name}") == ["Hello ", :name]
    assert Interpolation.to_interpolatable("%{solo}") == [:solo]
    assert Interpolation.to_interpolatable("%{foo}%{bar} %{baz}") == [:foo, :bar, " ", :baz]
    assert Interpolation.to_interpolatable("%{Your name} is cool!") == [:"Your name", " is cool!"]
    assert Interpolation.to_interpolatable("%{Héllø} there") == [:Héllø, " there"]
    assert Interpolation.to_interpolatable("foo %{} bar") == ["foo %{} bar"]
    assert Interpolation.to_interpolatable("%{") == ["%{"]
    assert Interpolation.to_interpolatable("abrupt ending %{") == ["abrupt ending %{"]

    assert Interpolation.to_interpolatable("incomplete %{ and then some") ==
             ["incomplete %{ and then some"]

    assert Interpolation.to_interpolatable("first empty %{} then %{ incomplete") ==
             ["first empty %{} then %{ incomplete"]

    assert Interpolation.to_interpolatable("") == []
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
