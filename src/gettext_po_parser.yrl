Nonterminals translations translation strings.
Terminals string msgid msgstr.
Rootsymbol translations.

translations ->
  translation translations : ['$1'|'$2'].

translations ->
  translation : ['$1'].

translation ->
  msgid strings msgstr strings : #{msgid => extract_strings('$2'),
                                   msgstr => extract_strings('$4')}.

strings ->
  string strings : ['$1'|'$2'].
strings ->
  string : ['$1'].

Erlang code.

extract_strings(Tokens) ->
  list_to_binary(lists:map(fun extract_string/1, Tokens)).

extract_string({string, _Line, String}) ->
  String.
