defmodule Gettext.InterpolationTest do
  use ExUnit.Case, async: true
  doctest Gettext.Interpolation
  alias Gettext.Interpolation

  test "to_interpolatable/1" do
    assert Interpolation.to_interpolatable("Hello %{name}")
           == ["Hello ", :name]
    assert Interpolation.to_interpolatable("%{foo}%{bar} %{baz}")
           == [:foo, :bar, " ", :baz]
    assert Interpolation.to_interpolatable("%{Your name} is cool!")
           == [:"Your name", " is cool!"]
  end

  test "missing_interpolation_keys/2" do
    bindings = %{
      foo: "foo",
      bar: "baz",
    }

    assert Interpolation.missing_interpolation_keys(bindings, [:foo, :bar, :baz])
           == "missing interpolation keys: baz"

    assert Interpolation.missing_interpolation_keys(bindings, [:foo, :bar, :a, :b, :c])
           == "missing interpolation keys: a, b, c"
  end

  test "interpolate/2: successful cases" do
    assert Interpolation.interpolate("Hello %{name}", %{name: "Alex"})
           == {:ok, "Hello Alex"}
    assert Interpolation.interpolate("%{count} errors", %{count: 3})
           == {:ok, "3 errors"}
  end

  test "interpolate/2: missing bindings" do
    assert Interpolation.interpolate("Hi %{name}", %{})
           == {:error, "missing interpolation keys: name"}
  end

  test "interpolate/2: unused bindings are ignored" do
    assert Interpolation.interpolate("Hi %{name}", %{name: "Sandra", foo: "bar"})
           == {:ok, "Hi Sandra"}
  end

  test "keys/1" do
    assert Interpolation.keys("Hello %{name}")
           == [:name]
    assert Interpolation.keys("It's %{time} here in %{state}")
           == [:time, :state]
    assert Interpolation.keys("Hi there %{your name}")
           == [:"your name"]
  end
end
