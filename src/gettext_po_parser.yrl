Nonterminals grammar translations translation pluralizations pluralization
             strings comments.
Terminals str msgid msgid_plural msgstr plural_form comment.
Rootsymbol grammar.

grammar ->
  translations : '$1'.

translations ->
  translation : ['$1'].
translations ->
  translation translations : ['$1'|'$2'].

translation ->
  comments msgid strings msgstr strings : {translation, #{
    comments => '$1',
    msgid    => single_or_list_of_strings('$3'),
    msgstr   => single_or_list_of_strings('$5')
  }}.
translation ->
  comments msgid strings msgid_plural strings pluralizations : {plural_translation, #{
    comments     => '$1',
    msgid        => single_or_list_of_strings('$3'),
    msgid_plural => single_or_list_of_strings('$5'),
    msgstr       => plural_forms_map_from_list('$6')
  }}.

pluralizations ->
  pluralization : ['$1'].
pluralizations ->
  pluralization pluralizations : ['$1'|'$2'].

pluralization ->
  msgstr plural_form strings : {'$2', single_or_list_of_strings('$3')}.

strings ->
  str : [extract_string('$1')].
strings ->
  str strings : [extract_string('$1')|'$2'].

comments ->
  '$empty' : [].
comments ->
  comment comments : [extract_comment('$1')|'$2'].


Erlang code.

single_or_list_of_strings([Str]) ->
  Str;
single_or_list_of_strings(Strings) ->
  Strings.

extract_string({str, _Line, String}) ->
  String.

plural_forms_map_from_list(Pluralizations) ->
  Tuples = lists:map(fun extract_plural_form/1, Pluralizations),
  maps:from_list(Tuples).

extract_plural_form({{plural_form, _Line, PluralForm}, String}) ->
  {PluralForm, String}.

extract_comment({comment, _Line, Contents}) ->
  Contents.
