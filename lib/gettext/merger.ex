defmodule Gettext.Merger do
  @moduledoc false

  alias Expo.PO
  alias Expo.Message
  alias Expo.Messages
  alias Gettext.Fuzzy
  alias Gettext.Plural

  @new_po_informative_comment """
  # "msgid"s in this file come from POT (.pot) files.
  ##
  ## Do not add, change, or remove "msgid"s manually here as
  ## they're tied to the ones in the corresponding POT file
  ## (with the same domain).
  ##
  ## Use "mix gettext.extract --merge" or "mix gettext.merge"
  ## to merge POT files into PO files.
  """

  @doc """
  Merges two `Gettext.PO` structs representing a PO file and an updated POT (or
  PO) file into a new `Gettext.PO` struct.

  `old` is an existing PO file (that contains messages) which will be
  "updated" with the messages in the `new` POT or PO file. messages in
  `old` will kept as long as they match with messages in `new`; all other
  messages will be discarded (as `new` is considered to be the reference).

  The `Gettext.PO` struct that this function returns is *always* meant to be a PO
  file, not a POT file.

  `new` can be:

    * a POT file (usually created or updated by the `mix gettext.extract` task) or
    * a newly created PO file with up-to-date source references (but old messages)

  Note that all translator comments in `new` will be discarded in favour of the
  ones in `old`. Reference comments and extracted comments will be taken from
  `new` instead.

  The following rules are observed:

    * matching messages are merged as follows:
      * existing msgstr are preserved (the ones in the POT file are empty anyways)
      * existing translator comments are preserved (there are no translator
        comments in POT files)
      * existing extracted comments are replaced by new extracted comments
      * existing references are discarded (as they're now outdated) and replaced
        by the references in the POT file

  """
  @spec merge(Messages.t(), Messages.t(), String.t(), Keyword.t(), Keyword.t()) ::
          {Messages.t(), map()}
  def merge(%Messages{} = old, %Messages{} = new, locale, opts, gettext_config)
      when is_binary(locale) and is_list(opts) do
    opts = put_plural_forms_opt(opts, old, locale)

    stats = %{new: 0, exact_matches: 0, fuzzy_matches: 0, removed: 0, marked_as_obsolete: 0}

    {messages, stats} = merge_messages(old.messages, new.messages, opts, gettext_config, stats)

    po = %Messages{
      top_comments: old.top_comments,
      headers: old.headers,
      file: old.file,
      messages: messages
    }

    {po, stats}
  end

  defp merge_messages(old, new, opts, gettext_config, stats) do
    fuzzy? = Keyword.fetch!(opts, :fuzzy)
    fuzzy_threshold = Keyword.fetch!(opts, :fuzzy_threshold)
    plural_forms = Keyword.fetch!(opts, :plural_forms)
    custom_flags_to_keep = Keyword.get(gettext_config, :custom_flags_to_keep, [])

    old = Map.new(old, &{Message.key(&1), &1})

    {messages, {stats, unused, _candidates}} =
      Enum.map_reduce(new, {stats, _unused = old, nil}, fn message,
                                                           {stats_acc, unused, candidates} ->
        key = Message.key(message)
        message = adjust_number_of_plural_forms(message, plural_forms)

        case Map.fetch(old, key) do
          {:ok, exact_match} ->
            stats = update_in(stats_acc.exact_matches, &(&1 + 1))

            {merge_two_messages(exact_match, message, custom_flags_to_keep),
             {stats, Map.delete(unused, key), candidates}}

          :error when fuzzy? ->
            candidates = candidates || prepare_fuzzy_candidates(old, key)

            case maybe_merge_fuzzy(message, candidates || old, key, fuzzy_threshold) do
              {:matched, match, fuzzy_merged} ->
                stats_acc = update_in(stats_acc.fuzzy_matches, &(&1 + 1))
                unused = Map.delete(unused, Message.key(match))

                fuzzy_merged =
                  if Keyword.get(opts, :store_previous_message_on_fuzzy_match, false) do
                    Map.update!(fuzzy_merged, :previous_messages, fn previous ->
                      Enum.uniq_by(previous ++ [match], &Message.key/1)
                    end)
                  else
                    fuzzy_merged
                  end

                {fuzzy_merged, {stats_acc, unused, candidates}}

              :nomatch ->
                stats_acc = update_in(stats_acc.new, &(&1 + 1))
                {message, {stats_acc, unused, candidates}}
            end

          :error ->
            stats_acc = update_in(stats_acc.new, &(&1 + 1))
            {message, {stats_acc, unused, candidates}}
        end
      end)

    messages = Enum.map(messages, &%{&1 | obsolete: false})

    {messages, stats} =
      case Keyword.get(opts, :on_obsolete, :delete) do
        :mark_as_obsolete ->
          {messages ++ (unused |> Map.values() |> Enum.map(&%{&1 | obsolete: true})),
           put_in(stats.marked_as_obsolete, map_size(unused))}

        :delete ->
          {messages, put_in(stats.removed, map_size(unused))}
      end

    {messages, stats}
  end

  defp adjust_number_of_plural_forms(%Message.Plural{} = message, plural_forms)
       when plural_forms > 0 do
    new_msgstr = Map.new(0..(plural_forms - 1), &{&1, [""]})
    %{message | msgstr: new_msgstr}
  end

  defp adjust_number_of_plural_forms(%Message.Singular{} = message, _plural_forms) do
    message
  end

  defp maybe_merge_fuzzy(message, candidates, key, fuzzy_threshold) do
    if matched = find_fuzzy_match(candidates, key, fuzzy_threshold) do
      {:matched, matched, Fuzzy.merge(message, matched)}
    else
      :nomatch
    end
  end

  defp prepare_fuzzy_candidates(messages, {_context, msgid}) do
    cond do
      # Jaro handles empty strings without traversing the other string. Avoid
      # indexing for these lookups, and leave malformed bytes to the scorer.
      msgid == "" or not String.valid?(msgid) ->
        nil

      Enum.all?(messages, fn {{_context, old_msgid}, _message} -> String.valid?(old_msgid) end) ->
        Enum.map(messages, fn {{_context, msgid}, message} ->
          graphemes = String.graphemes(msgid)
          {message, msgid, length(graphemes), Enum.frequencies(graphemes)}
        end)

      true ->
        # Pruning or stopping at a perfect match could hide a scorer exception
        # from another candidate. Preserve the full scan for malformed input.
        messages
    end
  end

  defp find_fuzzy_match(messages, key, threshold) when is_map(messages) do
    find_unpruned_match(messages, key, threshold)
  end

  defp find_fuzzy_match(candidates, {_context, msgid} = key, threshold) do
    if msgid == "" or not String.valid?(msgid) do
      messages = Enum.map(candidates, fn {message, msgid, _, _} -> {{nil, msgid}, message} end)
      find_unpruned_match(messages, key, threshold)
    else
      find_best_candidate(candidates, msgid, threshold)
    end
  end

  defp find_unpruned_match(messages, key, threshold) do
    matcher = Fuzzy.matcher(threshold)

    candidates =
      for {k, message} <- messages,
          match = matcher.(k, key),
          match != :nomatch,
          do: {message, match}

    if candidates == [] do
      nil
    else
      {message, _match} = Enum.max_by(candidates, fn {_t, {:match, distance}} -> distance end)
      message
    end
  end

  defp find_best_candidate(candidates, msgid, threshold) do
    graphemes = String.graphemes(msgid)
    size = length(graphemes)
    counts = graphemes |> Enum.frequencies() |> Enum.sort_by(fn {_, count} -> -count end)

    {message, _distance} =
      Enum.reduce_while(candidates, {nil, threshold}, fn
        {message, old_msgid, old_size, old_counts}, {best, best_distance} = acc ->
          if jaro_upper_bound(min(size, old_size), size, old_size) >= best_distance and
               enough_common_graphemes?(counts, old_counts, size, old_size, size, best_distance) do
            distance = String.jaro_distance(old_msgid, msgid)

            if distance >= best_distance and (is_nil(best) or distance > best_distance) do
              if distance == 1.0,
                do: {:halt, {message, distance}},
                else: {:cont, {message, distance}}
            else
              {:cont, acc}
            end
          else
            {:cont, acc}
          end
      end)

    message
  end

  # Matching graphemes cannot outnumber either string or their shared grapheme
  # counts. Assuming no transpositions gives an upper bound on Jaro similarity.
  # Keep the scorer's arithmetic order so inclusive thresholds stay inclusive.
  defp jaro_upper_bound(_matches, 0, 0), do: 1.0
  defp jaro_upper_bound(_matches, 0, _size), do: 0.0
  defp jaro_upper_bound(_matches, _size, 0), do: 0.0

  defp jaro_upper_bound(matches, size, old_size),
    do: (matches / size + matches / old_size + 1.0) / 3

  defp enough_common_graphemes?([], _old, _size, _old_size, _remaining, _target), do: true

  defp enough_common_graphemes?(
         [{grapheme, count} | rest],
         old,
         size,
         old_size,
         remaining,
         target
       ) do
    missing = max(count - Map.get(old, grapheme, 0), 0)
    remaining = remaining - missing

    (missing == 0 or jaro_upper_bound(min(remaining, old_size), size, old_size) >= target) and
      enough_common_graphemes?(rest, old, size, old_size, remaining, target)
  end

  # msgid, msgid_plural: they're the same
  # msgctxt: it's the same, even if it's not present (nil)
  # msgstr: new.msgstr should be empty since it comes from a POT file
  # comments: new has no translator comments as it comes from POT
  # extracted_comments: we should take the new most recent ones
  # flags: we should take the new flags and preserve the fuzzy flag
  # references: new contains the updated and most recent references

  defp merge_two_messages(old, new, custom_flags_to_keep) do
    old
    |> Message.merge(new)
    |> Map.merge(%{
      comments: old.comments,
      extracted_comments: new.extracted_comments,
      flags: merge_flags(old, new, custom_flags_to_keep),
      references: new.references
    })
  end

  defp merge_flags(old_message, new_message, custom_flags_to_keep) do
    # Force the "fuzzy" flag.
    flags_to_keep = Enum.uniq(["fuzzy" | custom_flags_to_keep])

    %{flags: flags} =
      Enum.reduce(flags_to_keep, new_message, fn flag, message ->
        if Message.has_flag?(old_message, flag) do
          Message.append_flag(message, flag)
        else
          message
        end
      end)

    flags
  end

  @doc """
  Returns the contents of a new PO file to be written at `po_file` from the POT
  template in `pot_file`.

  The new PO file will have:

    * the `Language` header set based on the locale (extracted from the path)
    * the messages of the POT file (no merging is needed as there are no
      messages in the PO file)

  Comments in `pot_file` that start with `##` will be discarded and not copied
  over the new PO file as they're meant to be comments generated by tools or
  comments directed to developers.
  """
  def new_po_file(po_file, pot_file, locale, opts) when is_binary(locale) and is_list(opts) do
    pot = PO.parse_file!(pot_file)
    opts = put_plural_forms_opt(opts, pot, locale)
    plural_forms = Keyword.fetch!(opts, :plural_forms)
    plural_forms_header = Keyword.fetch!(opts, :plural_forms_header)

    po = %Messages{
      top_comments: String.split(@new_po_informative_comment, "\n", trim: true),
      headers: headers_for_new_po_file(locale, plural_forms_header),
      file: po_file,
      messages: Enum.map(pot.messages, &prepare_new_message(&1, plural_forms))
    }

    stats = %{
      new: length(po.messages),
      exact_matches: 0,
      fuzzy_matches: 0,
      removed: 0,
      marked_as_obsolete: 0
    }

    {po, stats}
  end

  @doc false
  @spec prune_references(messages :: Messages.t(), gettext_config :: Keyword.t()) :: Messages.t()
  def prune_references(%Messages{} = all, gettext_config) when is_list(gettext_config) do
    cond do
      # Empty out all references.
      not Keyword.get(gettext_config, :write_reference_comments, true) ->
        put_in(all, [Access.key!(:messages), Access.all(), Access.key(:references)], [])

      # Remove lines from references and unique them.
      not Keyword.get(gettext_config, :write_reference_line_numbers, true) ->
        update_in(
          all,
          [Access.key!(:messages), Access.all(), Access.key(:references)],
          &remove_line_and_unique_references/1
        )

      true ->
        all
    end
  end

  defp remove_line_and_unique_references(references) do
    {unique_refs, _} =
      references
      |> update_in([Access.all(), Access.all()], fn
        {file, _line} -> file
        file -> file
      end)
      |> Enum.map_reduce(MapSet.new(), fn line, existing_references ->
        unique_line = Enum.uniq(line) -- MapSet.to_list(existing_references)
        {unique_line, MapSet.union(existing_references, MapSet.new(unique_line))}
      end)

    Enum.reject(unique_refs, &match?([], &1))
  end

  defp headers_for_new_po_file(locale, plural_forms_header) do
    [
      "",
      ~s(Language: #{locale}\n),
      ~s(Plural-Forms: #{plural_forms_header}\n)
    ]
  end

  defp prepare_new_message(message, plural_forms) do
    message
    |> strip_double_hash_comments()
    |> adjust_number_of_plural_forms(plural_forms)
  end

  defp strip_double_hash_comments(%{comments: comments} = message) do
    %{message | comments: Enum.reject(comments, &match?("#" <> _, &1))}
  end

  # TODO: simplify code here once we remove support for :plural_forms.
  defp put_plural_forms_opt(opts, messages, locale) do
    plural_mod = Application.get_env(:gettext, :plural_forms, Gettext.Plural)
    default_nplurals = plural_mod.nplurals(Plural.plural_info(locale, messages, plural_mod))

    opts = Keyword.put_new(opts, :plural_forms, default_nplurals)

    Keyword.put_new_lazy(opts, :plural_forms_header, fn ->
      requested_nplurals = Keyword.fetch!(opts, :plural_forms)

      # If nplurals is overridden to a non-default value by the user the
      # implementation will not be able to provide a correct header therefore
      # the header is just set to `nplurals=#{n}` and it is up to the user to
      # put a complete plural forms header themselves.
      if requested_nplurals == default_nplurals do
        Plural.plural_forms_header_impl(locale, messages, plural_mod)
      else
        "nplurals=#{requested_nplurals}"
      end
    end)
  end
end
