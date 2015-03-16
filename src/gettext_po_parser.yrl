Nonterminals translations translation strings.
Terminals string msgid msgstr.
Rootsymbol translations.

translations ->
  translation translations : ['$1'|'$2'].

translations ->
  translation : ['$1'].

translation ->
  msgid strings msgstr strings : {translation, {'$1', '$2'}, {'$3', '$4'}}.

strings ->
  string strings : ['$1'|'$2'].
strings ->
  string : ['$1'].
