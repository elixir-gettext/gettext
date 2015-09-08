Nonterminals grammar translations translation pluralizations pluralization
             strings comments.
Terminals str msgid msgid_plural msgstr plural_form comment.
Rootsymbol grammar.

grammar ->
  translations : '$1'.

translations ->
  '$empty' : [].
translations ->
  translation translations : ['$1'|'$2'].

translation ->
  comments msgid strings msgstr strings : {translation, #{
    comments       => '$1',
    msgid          => '$3',
    msgstr         => '$5',
    po_source_line => extract_line('$2')
  }}.
translation ->
  comments msgid strings msgid_plural strings pluralizations : {plural_translation, #{
    comments       => '$1',
    msgid          => '$3',
    msgid_plural   => '$5',
    msgstr         => plural_forms_map_from_list('$6'),
    po_source_line => extract_line('$2')
  }}.

pluralizations ->
  pluralization : ['$1'].
pluralizations ->
  pluralization pluralizations : ['$1'|'$2'].

pluralization ->
  msgstr plural_form strings : {'$2', '$3'}.

strings ->
  str : [extract_simple_token('$1')].
strings ->
  str strings : [extract_simple_token('$1')|'$2'].

comments ->
  '$empty' : [].
comments ->
  comment comments : [extract_simple_token('$1')|'$2'].


Erlang code.

extract_simple_token({_Token, _Line, Value}) ->
  Value.

extract_line({_Token, Line}) ->
  Line.

plural_forms_map_from_list(Pluralizations) ->
  Tuples = lists:map(fun extract_plural_form/1, Pluralizations),
  maps:from_list(Tuples).

extract_plural_form({{plural_form, _Line, PluralForm}, String}) ->
  {PluralForm, String}.
