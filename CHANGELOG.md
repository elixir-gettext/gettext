# Changelog

## Unreleased

  * Reduce the compile time of backends that use the default interpolation module by storing translations without interpolation in a literal map instead of generating one function clause each.
  * Add experimental `mix gettext.generate` task: messages are persisted as module attributes during normal compilation (for backends with `automatic_extraction: true` in the application environment, for example `config :gettext, MyApp.Gettext, automatic_extraction: true` in `config/dev.exs`) and read back from the compiled BEAM files, so extraction no longer needs to force-recompile the project.

## v1.1.0

  * Parallelize per-locale merging in `mix gettext.merge`.
  * Fix a bug where duplicate references for one message were recorded more than once.
  * Drastically improve performance of extraction in cases with many translations (tens of thousands or more).

## v1.0.2

  * Only skip manifest removal on Elixir v1.19.3+

## v1.0.1 (retired)

  * Remove unnecessary cleaning of Elixir manifests

## v1.0.0

This is the first 1.0 release of Gettext, a silly 10 years (and 6 months) after we started working on it. There are *very few changes* from the latest 0.26 release, and none of them are breaking.

Here are the new goodies:

  * Add support for concatenating sigils if all parts are known at compile time (such as `"Hello " <> ~s(world)`).
  * Significantly increase the timeout for `mix gettext.extract` to two minutes.
  * Add `Gettext.put_locale!/2`.

Happy 10+ years of Elixir translations everyone! 🎉

## Previous versions

[See the CHANGELOG for versions before v1.0](https://github.com/elixir-gettext/gettext/blob/v1.0.0/CHANGELOG.md).
