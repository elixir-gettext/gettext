# Changelog

## v1.0.1

  * Remove unnecessary cleaning of Elixir manifests

## v1.0.0

This is the first 1.0 release of Gettext, a silly 10 years (and 6 months) after we started working on it. There are *very few changes* from the latest 0.26 release, and none of them are breaking.

Here are the new goodies:

  * Add support for concatenating sigils if all parts are known at compile time (such as `"Hello " <> ~s(world)`).
  * Significantly increase the timeout for `mix gettext.extract` to two minutes.
  * Add `Gettext.put_locale!/1`.

Happy 10+ years of Elixir translations everyone! 🎉

## Previous versions

[See the CHANGELOG for versions before v1.0](https://github.com/elixir-gettext/gettext/blob/v1.0.0/CHANGELOG.md).
