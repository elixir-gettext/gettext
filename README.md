# Gettext

[![Build Status](https://travis-ci.org/elixir-lang/gettext.svg)](https://travis-ci.org/elixir-lang/gettext)

`gettext` is an internationalization (i18n) and localization (l10n) system commonly used for writing multilingual programs. Gettext is a standard for i18n in different communities, meaning there is a great set of tooling for developers and translators.

## Installation

TODO: Install instructions

TODO: Link to docs

## Usage

To use gettext, you must define a gettext module:

    defmodule MyApp.Gettext do
      use Gettext, otp_app: :my_app
    end

And invoke the gettext API, based on many `*gettext` functions:

    import MyApp.Gettext

    # Simple translation
    gettext "Here is the string to translate"

    # Plural translation
    ngettext "Here is the string to translate",
             "Here are the strings to translate",
             3

    # Domain-based translation
    dgettext "errors", "Here is the string to translate"

Translations in gettext are stored in Portable Object files (`.po`). The default domain should be placed at `priv/gettext/en/LC_MESSAGES/domain.po` with the following format:

    #: lib/foo/translation.ex:15
    msgid "Here is the string to translate"
    msgstr "Aqui está o texto para traduzir"

`.po` are text based and can be editted directly by translators. Some may even use existing tools for managing them, such as [Poedit](http://poedit.net/).

### Auto-synchronization

Because translations are based on strings, your source code does not lose readability as you still see literal strings, like `gettext "here is an example"`, instead of paths like `translate "some.path.convention"`. Furthermore, by adding `gettext "here is an example"`, your code continues to work as before, as `gettext` will return the given string if no translation is found.

Finally, due to the properties above, `gettext` is also able to synchronize `.po` files with your source code. For example, if you add the following to an Elixir file:

    gettext "Welcome back!"

Running `mix gettext.extract` will automatically sync all existing entries to `.pot` (template files). `.pot` files can then be merged into the `.po` files with `mix gettext.merge`.

## License

Copyright 2015 Plataformatec

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
