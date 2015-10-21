# Changelog

## v0.7.0

* When dumping PO files, dump as many references as possible on one line,
  wrapping at the 80th column
* Parse multiple references in the same reference comment
* Remove `Gettext.locale/0-1` and `Gettext.with_locale/2` in favour of
  `Gettext.put_locale/2`, `Gettext.get_locale/2`, and `Gettext.with_locale/3`
  which now work by setting/getting the locale on a per-backend basis (instead
  of a global one)
* Remove the `:default_locale` config option for the `:gettext` application in
  favour of configuring the `:default_locale` for backends tied to their
  `:otp_app` (e.g., `config :my_app, MyApp.Gettext, default_locale: "pt_BR"`)

## v0.6.1

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
