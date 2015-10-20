# Changelog

## v0.7.0-dev

* When dumping PO files, dump as many references as possible on one line,
  wrapping at the 80th column
* Parse multiple references in the same reference comment

## v0.6.1

Bugfixes

* Fix a bug with the `mix gettext.merge` task that was failing in Elixir v1.1.1
  because `0.5 in 0..1` returns `false` with it

## v0.6.0

* Add a `:flags` field to the `Gettext.PO.Translation` and
  `Gettext.PO.PluralTranslation` structs
* Add support for fuzzy matching translations in `gettext.merge` and
  `gettext.extract --merge`
* Add the `:fuzzy_threshold` configuration option for the `:gettext` application

## v0.5.0

* Initial release
