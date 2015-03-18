Nonterminals grammar translations translation strings.
Terminals string msgid msgstr.
Rootsymbol grammar.

grammar ->
  translations : '$1'.

translations ->
  translation : ['$1'].
translations ->
  translation translations : ['$1'|'$2'].

translation ->
  msgid strings msgstr strings : #{msgid => concat('$2'), msgstr => concat('$4')}.

strings ->
  string : ['$1'].
strings ->
  string strings : ['$1'|'$2'].


Erlang code.

concat(Tokens) ->
  Strings = lists:map(fun extract_string/1, Tokens),
  list_to_binary(Strings).

extract_string({string, _Line, String}) ->
  String.
