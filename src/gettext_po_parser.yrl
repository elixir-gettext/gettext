Nonterminals grammar translations translation pluralizations pluralization strings.
Terminals str msgid msgid_plural msgstr plural_form.
Rootsymbol grammar.

grammar ->
  translations : '$1'.

translations ->
  translation : ['$1'].
translations ->
  translation translations : ['$1'|'$2'].

translation ->
  msgid strings msgstr strings : {translation, #{
    msgid => concat('$2'),
    msgstr => concat('$4')
  }}.
translation ->
  msgid strings msgid_plural strings pluralizations : {plural_translation, #{
    msgid        => concat('$2'),
    msgid_plural => concat('$4'),
    msgstr       => plural_forms_map_from_list('$5')
  }}.

pluralizations ->
  pluralization : ['$1'].
pluralizations ->
  pluralization pluralizations : ['$1'|'$2'].

pluralization ->
  msgstr plural_form strings : {'$2', concat('$3')}.

strings ->
  str : ['$1'].
strings ->
  str strings : ['$1'|'$2'].


Erlang code.

concat(Tokens) ->
  Strings = lists:map(fun extract_string/1, Tokens),
  list_to_binary(Strings).

extract_string({str, _Line, String}) ->
  String.

plural_forms_map_from_list(Pluralizations) ->
  Tuples = lists:map(fun extract_plural_form/1, Pluralizations),
  maps:from_list(Tuples).

extract_plural_form({{plural_form, _Line, PluralForm}, String}) ->
  {PluralForm, String}.
