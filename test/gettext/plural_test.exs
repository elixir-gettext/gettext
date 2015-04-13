defmodule Gettext.PluralTest do
  use ExUnit.Case, async: true
  alias Gettext.Plural

  test "works for Polish" do
    assert Plural.nplurals("pl") == 3

    assert Plural.plural("pl", 1) == 0
    assert Plural.plural("pl", 2) == 1
    assert Plural.plural("pl", 5) == 2
    assert Plural.plural("pl", 112) == 2
  end

  test "works for Italian" do
    assert Plural.nplurals("it") == 2

    assert Plural.plural("it", 1) == 0
    assert Plural.plural("it", 0) == 1
    assert Plural.plural("it", 100) == 1
  end
end
