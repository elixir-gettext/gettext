defmodule Gettext.Merger do
  @moduledoc false

  alias Expo.PO
  alias Expo.Message
  alias Expo.Messages
  alias Gettext.Fuzzy

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
  @spec merge(Messages.t(), Messages.t(), String.t(), Keyword.t()) ::
          {Messages.t(), map()}
  def merge(%Messages{} = old, %Messages{} = new, locale, opts)
      when is_binary(locale) and is_list(opts) do
    opts = put_plural_forms_opt(opts, old.headers, locale)
    stats = %{new: 0, exact_matches: 0, fuzzy_matches: 0, removed: 0, marked_as_obsolete: 0}

    {messages, stats} = merge_messages(old.messages, new.messages, opts, stats)

    po = %Messages{
      top_comments: old.top_comments,
      headers: old.headers,
      file: old.file,
      messages: messages
    }

    {po, stats}
  end

  defp merge_messages(old, new, opts, stats) do
    fuzzy? = Keyword.fetch!(opts, :fuzzy)
    fuzzy_threshold = Keyword.fetch!(opts, :fuzzy_threshold)
    plural_forms = Keyword.fetch!(opts, :plural_forms)

    old = Map.new(old, &{Message.key(&1), &1})

    {messages, {stats, unused}} =
      Enum.map_reduce(new, {stats, _unused = old}, fn message, {stats_acc, unused} ->
        key = Message.key(message)
        message = adjust_number_of_plural_forms(message, plural_forms)

        case Map.fetch(old, key) do
          {:ok, exact_match} ->
            stats = update_in(stats_acc.exact_matches, &(&1 + 1))
            {merge_two_messages(exact_match, message), {stats, Map.delete(unused, key)}}

          :error when fuzzy? ->
            case maybe_merge_fuzzy(message, old, key, fuzzy_threshold) do
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

                {fuzzy_merged, {stats_acc, unused}}

              :nomatch ->
                stats_acc = update_in(stats_acc.new, &(&1 + 1))
                {message, {stats_acc, unused}}
            end

          :error ->
            stats_acc = update_in(stats_acc.new, &(&1 + 1))
            {message, {stats_acc, unused}}
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

  defp maybe_merge_fuzzy(message, old, key, fuzzy_threshold) do
    if matched = find_fuzzy_match(old, key, fuzzy_threshold) do
      {:matched, matched, Fuzzy.merge(message, matched)}
    else
      :nomatch
    end
  end

  defp find_fuzzy_match(messages, key, threshold) do
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

  # msgid, msgid_plural: they're the same
  # msgctxt: it's the same, even if it's not present (nil)
  # msgstr: new.msgstr should be empty since it comes from a POT file
  # comments: new has no translator comments as it comes from POT
  # extracted_comments: we should take the new most recent ones
  # flags: we should take the new flags and preserve the fuzzy flag
  # references: new contains the updated and most recent references

  defp merge_two_messages(%Message.Singular{} = old, %Message.Singular{} = new) do
    %Message.Singular{
      msgctxt: new.msgctxt,
      msgid: new.msgid,
      msgstr: old.msgstr,
      comments: old.comments,
      extracted_comments: new.extracted_comments,
      flags: merge_flags(old, new),
      references: new.references
    }
  end

  defp merge_two_messages(%Message.Plural{} = old, %Message.Plural{} = new) do
    %Message.Plural{
      msgctxt: new.msgctxt,
      msgid: new.msgid,
      msgid_plural: new.msgid_plural,
      msgstr: old.msgstr,
      comments: old.comments,
      extracted_comments: new.extracted_comments,
      flags: merge_flags(old, new),
      references: new.references
    }
  end

  defp merge_flags(old, new) do
    if Message.has_flag?(old, "fuzzy") do
      Message.append_flag(new, "fuzzy").flags
    else
      new.flags
    end
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
    opts = put_plural_forms_opt(opts, pot.headers, locale)
    plural_forms = Keyword.fetch!(opts, :plural_forms)

    po = %Messages{
      top_comments: String.split(@new_po_informative_comment, "\n", trim: true),
      headers: headers_for_new_po_file(locale, plural_forms),
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
    write_references? = Keyword.get(gettext_config, :write_reference_comments, true)
    write_line_numbers? = Keyword.get(gettext_config, :write_reference_line_numbers, true)

    cond do
      not write_references? ->
        put_in(all, [Access.key!(:messages), Access.all(), Access.key(:references)], [])

      not write_line_numbers? ->
        accessor = [
          Access.key!(:messages),
          Access.all(),
          Access.key!(:references),
          Access.all(),
          Access.all()
        ]

        update_in(all, accessor, fn
          {file, _line_number} -> file
          file -> file
        end)

      true ->
        all
    end
  end

  defp headers_for_new_po_file(locale, plural_forms) do
    [
      "",
      ~s(Language: #{locale}\n),
      ~s(Plural-Forms: nplurals=#{plural_forms}\n)
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

  defp put_plural_forms_opt(opts, headers, locale) do
    Keyword.put_new_lazy(opts, :plural_forms, fn ->
      read_plural_forms_from_headers(headers) ||
        Application.get_env(:gettext, :plural_forms, Gettext.Plural).nplurals(locale)
    end)
  end

  defp read_plural_forms_from_headers(headers) do
    Enum.find_value(headers, fn header ->
      with "Plural-Forms:" <> rest <- header,
           "nplurals=" <> rest <- String.trim(rest),
           {plural_forms, _rest} <- Integer.parse(rest) do
        plural_forms
      else
        _other -> nil
      end
    end)
  end
end
