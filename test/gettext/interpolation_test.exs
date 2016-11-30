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

  test "keys/1" do
    # With a string as its argument
    assert Interpolation.keys("Hello %{name}")
           == [:name]
    assert Interpolation.keys("It's %{time} here in %{state}")
           == [:time, :state]
    assert Interpolation.keys("Hi there %{your name}")
           == [:"your name"]
    assert Interpolation.keys("Hello %{name} in %{state} goodbye %{name}")
           == [:name, :state]

    # With a list of segments as its argument
    assert Interpolation.keys(["Hello ", :name, " it's ", :time, " goodbye ", :name])
           == [:name, :time]
  end
end
