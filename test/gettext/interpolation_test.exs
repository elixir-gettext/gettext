defmodule Gettext.InterpolationTest do
  use ExUnit.Case, async: true

  doctest Gettext.Interpolation

  alias Gettext.Interpolation

  require Interpolation

  test "runtime_interpolate/2" do
    interpolatable = Interpolation.to_interpolatable("%{a} %{b} %{c}")

    assert Interpolation.runtime_interpolate(interpolatable, %{a: 1, b: :two, c: "thr ee"}) ==
             {:ok, "1 two thr ee"}

    assert Interpolation.runtime_interpolate(interpolatable, %{a: "a"}) ==
             {:missing_bindings, "a %{b} %{c}", [:b, :c]}

    interpolatable = Interpolation.to_interpolatable("%{a} %{a} %{a}")

    assert Interpolation.runtime_interpolate(interpolatable, %{a: "foo"}) == {:ok, "foo foo foo"}

    assert Interpolation.runtime_interpolate(interpolatable, %{b: "bar"}) ==
             {:missing_bindings, "%{a} %{a} %{a}", [:a]}

    assert Interpolation.runtime_interpolate("%{a} %{b} %{c}", %{a: "a"}) ==
             {:missing_bindings, "a %{b} %{c}", [:b, :c]}
  end

  test "to_interpolatable/1" do
    assert Interpolation.to_interpolatable("Hello %{name}") == ["Hello ", :name]
    assert Interpolation.to_interpolatable("%{solo}") == [:solo]
    assert Interpolation.to_interpolatable("%{foo}%{bar} %{baz}") == [:foo, :bar, " ", :baz]
    assert Interpolation.to_interpolatable("%{Your name} is cool!") == [:"Your name", " is cool!"]
    assert Interpolation.to_interpolatable("foo %{} bar") == ["foo %{} bar"]
    assert Interpolation.to_interpolatable("%{") == ["%{"]
    assert Interpolation.to_interpolatable("abrupt ending %{") == ["abrupt ending %{"]

    assert Interpolation.to_interpolatable("incomplete %{ and then some") ==
             ["incomplete %{ and then some"]

    assert Interpolation.to_interpolatable("first empty %{} then %{ incomplete") ==
             ["first empty %{} then %{ incomplete"]

    assert Interpolation.to_interpolatable("") == []
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

  describe "compile_interpolate/3" do
    test "interpolates complete bindings" do
      assert {:ok, "Hello World!"} ==
               Interpolation.compile_interpolate(:translation, "Hello %{name}!", %{name: "World"})
    end

    test "interpolates incomplete bindings" do
      assert {:missing_bindings, "Hello %{name}!", [:name]} ==
               Interpolation.compile_interpolate(:translation, "Hello %{name}!", %{
                 unused: "binding"
               })
    end

    test "interpolates no bindings" do
      assert {:missing_bindings, "Hello %{name}!", [:name]} ==
               Interpolation.compile_interpolate(:translation, "Hello %{name}!", %{})
    end

    test "rejects dynamic message" do
      assert_raise RuntimeError, fn ->
        Code.eval_quoted(
          quote do
            require Interpolation

            Interpolation.compile_interpolate(
              :translation,
              "dynamic message " <> inspect(make_ref()),
              %{}
            )
          end
        )
      end
    end

    test "optimizes plural translation without count" do
      translate = fn bindings ->
        Interpolation.compile_interpolate(
          :plural_translation,
          "%{count} shoes",
          bindings
        )
      end

      assert_raise MatchError, fn ->
        translate.(%{})
      end

      assert {:ok, "7 shoes"} = translate.(%{count: 7})
    end
  end
end
