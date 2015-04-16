defmodule Gettext.InterpolationTest do
  use ExUnit.Case, async: true
  alias Gettext.Interpolation

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
    assert Interpolation.interpolate("Hello %{name}", name: "Alex")
           == {:ok, "Hello Alex"}
    assert Interpolation.interpolate("%{count} errors", %{count: 3})
           == {:ok, "3 errors"}
  end

  test "interpolate/2: missing bindings" do
    assert Interpolation.interpolate("Hi %{name}", %{})
           == {:error, "missing interpolation keys: name"}
  end

  test "interpolate/2: unused bindings are ignored" do
    assert Interpolation.interpolate("Hi %{name}", name: "Sandra", foo: "bar")
           == {:ok, "Hi Sandra"}
  end
end
