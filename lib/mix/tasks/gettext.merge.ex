defmodule Mix.Tasks.Gettext.Merge do
  use Mix.Task
  @recursive true

  @shortdoc "Merge template files into translation files"

  @moduledoc """
  Merges PO/POT files with PO files.

  This task is used when translations in the source code change: when they do,
  `mix gettext.extract` is usually used to extract the new translations to POT
  files. At this point, developers or translators can use this task to "sync"
  the newly updated POT files with the existing locale-specific PO files. All
  the metadata for each translation (like position in the source code, comments
  and so on) is taken from the newly updated POT file; the only things taken
  from the PO file are the actual translated strings.

  #### Fuzzy matching

  Translations in the updated PO/POT file that have an exact match (a
  translation with the same msgid) in the old PO file are merged as described
  above. When a translation in the update PO/POT files has no match in the old
  PO file, a fuzzy match for that translation is attempted. For example, assume
  we have this POT file:

      msgid "hello, world!"
      msgstr ""

  and we merge it with this PO file:

      # notice no exclamation point here
      msgid "hello, world"
      msgstr "ciao, mondo"

  Since the two translations are very similar, the msgstr from the existing
  translation will be taken over to the new translation, which will however be
  marked as *fuzzy*:

      #, fuzzy
      msgid "hello, world!"
      msgstr "ciao, mondo"

  Generally, a `fuzzy` flag calls for review from a translator.

  Fuzzy matching can be configured (for example, the threshold for translation
  similarity can be tweaked) or disabled entirely; lool at the "Options" section
  below.

  ## Usage

      mix gettext.merge OLD_FILE UPDATED_FILE [OPTIONS]
      mix gettext.merge DIR [OPTIONS]

  If two files are given as arguments, they must be a `.po` file and a
  `.po`/`.pot` file. The first one is the old PO file, while the second one is
  the last generated one. They are merged and written over the first file. For
  example:

      mix gettext.merge priv/gettext/en/LC_MESSAGES/default.po priv/gettext/default.pot

  If only one argument is given, then that argument must be a directory
  containing Gettext translations (with `.pot` files at the root level alongside
  locale directories - this is usually a "backend" directory used by a Gettext
  backend, see `Gettext.Backend`).

      mix gettext.merge priv/gettext

  If the `--locale LOCALE` option is given, then only the PO files in
  `DIR/LOCALE/LC_MESSAGES` will be merged with the POT files in `DIR`. If no
  options are given, then all the PO files for all locales under `DIR` are
  merged with the POT files in `DIR`.

  ## Plural forms

  By default, Gettext will determine the number of plural forms for newly generated translations
  by checking the value of `nplurals` in the `Plural-Forms` header in the existing `.po` file. If
  a `.po` file doesn't already exist and Gettext is creating a new one or if the `Plural-Forms`
  header is not in the `.po` file, Gettext will use the number of plural forms that
  `Gettext.Plural` returns for the locale of the file being created. The number of plural forms
  can be forced through the `--plural-forms` option (see below).

  ## Options

    * `--locale` - a string representing a locale. If this is provided, then only the PO
      files in `DIR/LOCALE/LC_MESSAGES` will be merged with the POT files in `DIR`. This
      option can only be given when a single argument is passed to the task
      (a directory).

    * `--no-fuzzy` - stops fuzzy matching from being performed when merging
      files.

    * `--fuzzy-threshold` - a float between `0` and `1` which represents the
      miminum Jaro distance needed for two translations to be considered a fuzzy
      match. Overrides the global `:fuzzy_threshold` option (see the docs for
      `Gettext` for more information on this option).

    * `--plural-forms` - a integer strictly greater than `0`. If this is passed,
      new translations in the target PO files will have this number of empty
      plural forms. See the "Plural forms" section above.

  """

  @default_fuzzy_threshold 0.8
  @switches [
    locale: :string,
    fuzzy: :boolean,
    fuzzy_threshold: :float,
    plural_forms: :integer
  ]

  alias Gettext.{Merger, PO}

  def run(args) do
    _ = Mix.Project.get!()
    gettext_config = Mix.Project.config()[:gettext] || []

    case OptionParser.parse!(args, switches: @switches) do
      {opts, [po_file, reference_file]} ->
        merge_two_files(po_file, reference_file, opts, gettext_config)

      {opts, [translations_dir]} ->
        merge_translations_dir(translations_dir, opts, gettext_config)

      {_opts, []} ->
        Mix.raise(
          "gettext.merge requires at least one argument to work. " <>
            "Use `mix help gettext.merge` to see the usage of this task"
        )

      {_opts, _args} ->
        Mix.raise(
          "Too many arguments for the gettext.merge task. " <>
            "Use `mix help gettext.merge` to see the usage of this task"
        )
    end

    Mix.Task.reenable("gettext.merge")
  end

  defp merge_two_files(po_file, reference_file, opts, gettext_config) do
    merging_opts = validate_merging_opts!(opts, gettext_config)

    if Path.extname(po_file) == ".po" and Path.extname(reference_file) in [".po", ".pot"] do
      ensure_file_exists!(po_file)
      ensure_file_exists!(reference_file)
      locale = locale_from_path(po_file)
      contents = merge_files(po_file, reference_file, locale, merging_opts, gettext_config)
      write_file(po_file, contents)
    else
      Mix.raise("Arguments must be a PO file and a PO/POT file")
    end
  end

  defp merge_translations_dir(dir, opts, gettext_config) do
    ensure_dir_exists!(dir)
    merging_opts = validate_merging_opts!(opts, gettext_config)

    if locale = opts[:locale] do
      merge_locale_dir(dir, locale, merging_opts, gettext_config)
    else
      merge_all_locale_dirs(dir, merging_opts, gettext_config)
    end
  end

  defp merge_locale_dir(pot_dir, locale, opts, gettext_config) do
    locale_dir = locale_dir(pot_dir, locale)
    create_missing_locale_dir(locale_dir)
    merge_dirs(locale_dir, pot_dir, locale, opts, gettext_config)
  end

  defp merge_all_locale_dirs(pot_dir, opts, gettext_config) do
    for locale <- File.ls!(pot_dir), File.dir?(Path.join(pot_dir, locale)) do
      merge_dirs(locale_dir(pot_dir, locale), pot_dir, locale, opts, gettext_config)
    end
  end

  def locale_dir(pot_dir, locale) do
    Path.join([pot_dir, locale, "LC_MESSAGES"])
  end

  defp merge_dirs(po_dir, pot_dir, locale, opts, gettext_config) do
    merger = fn pot_file ->
      po_file = find_matching_po(pot_file, po_dir)
      contents = merge_or_create(pot_file, po_file, locale, opts, gettext_config)
      write_file(po_file, contents)
    end

    pot_dir
    |> Path.join("*.pot")
    |> Path.wildcard()
    |> Task.async_stream(merger, ordered: false, timeout: 10_000)
    |> Stream.run()

    warn_for_po_without_pot(po_dir, pot_dir)
  end

  defp find_matching_po(pot_file, po_dir) do
    domain = Path.basename(pot_file, ".pot")
    Path.join(po_dir, "#{domain}.po")
  end

  defp merge_or_create(pot_file, po_file, locale, opts, gettext_config) do
    if File.regular?(po_file) do
      merge_files(po_file, pot_file, locale, opts, gettext_config)
    else
      Merger.new_po_file(po_file, pot_file, locale, opts, gettext_config)
    end
  end

  defp merge_files(po_file, pot_file, locale, opts, gettext_config) do
    merged = Merger.merge(PO.parse_file!(po_file), PO.parse_file!(pot_file), locale, opts)
    PO.dump(merged, gettext_config)
  end

  defp write_file(path, contents) do
    File.write!(path, contents)
    Mix.shell().info("Wrote #{path}")
  end

  # Warns for every PO file that has no matching POT file.
  defp warn_for_po_without_pot(po_dir, pot_dir) do
    po_dir
    |> Path.join("*.po")
    |> Path.wildcard()
    |> Enum.reject(&po_has_matching_pot?(&1, pot_dir))
    |> Enum.each(fn po_file ->
      Mix.shell().info("Warning: PO file #{po_file} has no matching POT file in #{pot_dir}")
    end)
  end

  defp po_has_matching_pot?(po_file, pot_dir) do
    domain = Path.basename(po_file, ".po")
    pot_path = Path.join(pot_dir, "#{domain}.pot")
    File.exists?(pot_path)
  end

  defp ensure_file_exists!(path) do
    unless File.regular?(path), do: Mix.raise("No such file: #{path}")
  end

  defp ensure_dir_exists!(path) do
    unless File.dir?(path), do: Mix.raise("No such directory: #{path}")
  end

  defp create_missing_locale_dir(dir) do
    unless File.dir?(dir) do
      File.mkdir_p!(dir)
      Mix.shell().info("Created directory #{dir}")
    end
  end

  defp validate_merging_opts!(opts, gettext_config) do
    opts =
      opts
      |> Keyword.take([:fuzzy, :fuzzy_threshold, :plural_forms])
      |> Keyword.put_new(:fuzzy, true)
      |> Keyword.put_new_lazy(:fuzzy_threshold, fn ->
        gettext_config[:fuzzy_threshold] || @default_fuzzy_threshold
      end)

    threshold = opts[:fuzzy_threshold]

    unless threshold >= 0.0 and threshold <= 1.0 do
      Mix.raise("The :fuzzy_threshold option must be a float >= 0.0 and <= 1.0")
    end

    opts
  end

  defp locale_from_path(path) do
    parts = Path.split(path)
    index = Enum.find_index(parts, &(&1 == "LC_MESSAGES"))
    Enum.at(parts, index - 1)
  end
end
