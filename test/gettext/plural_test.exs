defmodule Gettext.PluralTest do
  use ExUnit.Case, async: true

  import Gettext.Plural, only: [nplurals: 1, plural: 2]

  alias Gettext.Plural.UnknownLocaleError

  test "x_* locales are pluralized like x except for exceptions" do
    assert nplurals("en") == nplurals("en_GB")

    assert plural("pt", 0) == 1
    assert plural("pt", 1) == 0
    assert plural("pt_BR", 0) == 0
    assert plural("pt_BR", 1) == 0
  end

  test "locale with a country" do
    # The _XX in en_XX gets stripped and en_XX is pluralized as en.
    assert nplurals("en_XX") == nplurals("en")
    assert plural("en_XX", 100) == plural("en", 100)
  end

  test "unknown locale" do
    message = ~r/unknown locale "wat"/
    assert_raise UnknownLocaleError, message, fn -> nplurals("wat") end
    assert_raise UnknownLocaleError, message, fn -> plural("wat", 1) end

    # This happens with dash as the country/locale separator
    # (https://en.wikipedia.org/wiki/IETF_language_tag).
    message = ~r/unknown locale "en-us"/
    assert_raise UnknownLocaleError, message, fn -> nplurals("en-us") end
  end

  test "locales with one form" do
    assert nplurals("ja") == 1
    assert plural("ja", 0) == 0
    assert plural("ja", 8) == 0
  end

  test "locales with two forms where 0 is same as > 1" do
    assert nplurals("it") == 2
    assert plural("it", 1) == 0
    assert plural("it", 0) == 1
    assert plural("it", 13) == 1
  end

  test "locales with two forms where 0 and 1 are the same" do
    assert nplurals("fr") == 2
    assert plural("fr", 0) == 0
    assert plural("fr", 1) == 0
    assert plural("fr", 2) == 1
  end

  test "locales that belong to the 3-forms slavic family" do
    assert nplurals("ru") == 3
    assert plural("ru", 21) == 0
    assert plural("ru", 42) == 1
    assert plural("ru", 11) == 2
  end

  test "locales that belong to the alternative 3-forms slavic family" do
    assert nplurals("cs") == 3
    assert plural("cs", 1) == 0
    assert plural("cs", 3) == 1
    assert plural("cs", 12) == 2
  end

  test "locales that don't belong to any pluralization family" do
    assert plural("ar", 0) == 0
    assert plural("ar", 1) == 1
    assert plural("ar", 2) == 2
    assert plural("ar", 505) == 3
    assert plural("ar", 733) == 4
    assert plural("ar", 101) == 5

    assert plural("csb", 1) == 0
    assert plural("csb", 33) == 1
    assert plural("csb", 115) == 2

    assert plural("cy", 1) == 0
    assert plural("cy", 2) == 1
    assert plural("cy", 23) == 2
    assert plural("cy", 8) == 3

    assert plural("ga", 1) == 0
    assert plural("ga", 2) == 1
    assert plural("ga", 4) == 2
    assert plural("ga", 10) == 3
    assert plural("ga", 133) == 4

    assert plural("gd", 1) == 0
    assert plural("gd", 12) == 1
    assert plural("gd", 18) == 2
    assert plural("gd", 20) == 3

    assert plural("is", 71) == 0
    assert plural("is", 11) == 1

    assert plural("jv", 0) == 0
    assert plural("jv", 13) == 1

    assert plural("kw", 1) == 0
    assert plural("kw", 2) == 1
    assert plural("kw", 3) == 2
    assert plural("kw", 99) == 3

    assert plural("lt", 81) == 0
    assert plural("lt", 872) == 1
    assert plural("lt", 112) == 2

    assert plural("lv", 31) == 0
    assert plural("lv", 9) == 1
    assert plural("lv", 0) == 2

    assert plural("mk", 131) == 0
    assert plural("mk", 132) == 1
    assert plural("mk", 9) == 2

    assert plural("mnk", 0) == 0
    assert plural("mnk", 1) == 1
    assert plural("mnk", 12) == 2

    assert plural("mt", 1) == 0
    assert plural("mt", 0) == 1
    assert plural("mt", 119) == 2
    assert plural("mt", 67) == 3

    assert plural("pl", 1) == 0
    assert plural("pl", 102) == 1
    assert plural("pl", 713) == 2

    assert plural("ro", 1) == 0
    assert plural("ro", 19) == 1
    assert plural("ro", 80) == 2

    assert plural("sl", 320) == 0
    assert plural("sl", 101) == 1
    assert plural("sl", 202) == 2
    assert plural("sl", 303) == 3
  end
end
