defmodule Gettext.PluralTest do
  use ExUnit.Case, async: true
  alias Gettext.Plural
  alias Gettext.Plural.UnknownLocaleError

  test "x_* locales are pluralized like x except for exceptions" do
    assert Plural.nplurals("en") == Plural.nplurals("en_GB")

    assert Plural.plural("pt", 0) == 1
    assert Plural.plural("pt", 1) == 0
    assert Plural.plural("pt_BR", 0) == 0
    assert Plural.plural("pt_BR", 1) == 0
  end

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

  test "locale with a country" do
    # The _XX in en_XX gets stripped and en_XX is pluralized as en.
    assert Plural.nplurals("en_XX") == Plural.nplurals("en")
    assert Plural.plural("en_XX", 100) == Plural.plural("en", 100)
  end

  test "unknown locale" do
    message = ~r/unknown locale "wat"/
    assert_raise UnknownLocaleError, message, fn -> Plural.nplurals("wat") end
    assert_raise UnknownLocaleError, message, fn -> Plural.plural("wat", 1) end

    # This happens with dash as the country/locale separator
    # (https://en.wikipedia.org/wiki/IETF_language_tag).
    message = ~r/unknown locale "en-us"/
    assert_raise UnknownLocaleError, message, fn -> Plural.nplurals("en-us") end
  end
end
