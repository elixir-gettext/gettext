defmodule Mix.Tasks.Gettext.Merge do
  use Mix.Task
  @recursive true

  @shortdoc "Merge template files into translation files"

  @moduledoc """
  Merges template files (`.pot` files) into translation files (`.po` files).

  If two files are given as arguments, they must be a `.po` and a `.po`/`.pot`
  file). The first one is the old PO file, while the second one is the last
  generated one. They are merged and written over the first file.

      mix gettext.merge priv/gettext/en/LC_MESSAGES/default.pot priv/gettext/default.pot

  If one file is given as an argument, then that file must be a directory
  containing gettext translations (with `.pot` files at the root level alongside
  locale directories).

      mix gettext.merge DIR

  If the `--locale LOCALE` option is given, then only the PO files in
  `DIR/LOCALE/LC_MESSAGES` will be merged with the POT files in `DIR`. If no
  options are given, then all the PO files for all locales under `DIR` are
  merged with the POT files in `DIR`.
  """

  alias Gettext.Merger

  def run(args) do
    _ = Mix.Project.get!

    case OptionParser.parse(args, strict: [locale: :string]) do
      {opts, [arg1, arg2], _} ->
        run_with_two_args(arg1, arg2, opts)
      {opts, [arg], _} ->
        run_with_one_arg(arg, opts)
      {_, [], _} ->
        Mix.raise "gettext.merge requires at least one argument to work." <>
                  "Use `mix help gettext.merge` to see the usage of this task."
      {_, _, _} ->
        Mix.raise "Too many arguments for the gettext.merge task. " <>
                  "Use `mix help gettext.merge` to see the usage of this task."
    end
  end

  defp run_with_two_args(arg1, arg2, []) do
    if Path.extname(arg1) == ".po" and Path.extname(arg2) in [".po", ".pot"] do
      ensure_file_exists!(arg1)
      ensure_file_exists!(arg2)
      {path, contents} = merge_po_with_pot(arg1, arg2)
      File.write!(path, contents)
      Mix.shell.info "Wrote #{path}"
    else
      Mix.raise "Arguments must be a PO file and a PO/POT file"
    end
  end

  defp run_with_one_arg(arg, opts) do
    ensure_dir_exists!(arg)

    if locale = opts[:locale] do
      merge_locale_dir(arg, locale)
    else
      merge_all_locale_dirs(arg)
    end
  end

  defp merge_po_with_pot(po_file, pot_file) do
    {po_file, Merger.merge_files(po_file, pot_file)}
  end

  defp merge_locale_dir(pot_dir, locale) do
    locale_dir = locale_dir(pot_dir, locale)
    ensure_dir_exists!(locale_dir)
    merge_dirs(locale_dir, pot_dir)
  end

  defp merge_all_locale_dirs(pot_dir) do
    pot_dir
    |> ls_locale_dirs
    |> Enum.each(&merge_dirs(&1, pot_dir))
  end

  defp locale_dir(dir, locale) do
    Path.join([dir, locale, "LC_MESSAGES"])
  end

  defp ls_locale_dirs(dir) do
    dir
    |> File.ls!
    |> Enum.filter(&File.dir?(Path.join(dir, &1)))
    |> Enum.map(&locale_dir(dir, &1))
  end

  defp merge_dirs(po_dir, pot_dir) do
    pot_dir
    |> Path.join("**/*.pot")
    |> Path.wildcard()
    |> Enum.map(&find_matching_po(&1, po_dir))
    |> Enum.map(&merge_or_create/1)
    |> Enum.each(&write_file/1)

    # Now warn for every PO file that has no matching POT file.
    po_dir
    |> Path.join("**/*.po")
    |> Path.wildcard()
    |> Enum.reject(&po_has_matching_pot?(&1, pot_dir))
    |> Enum.map(&warn_for_missing_pot_file(&1, pot_dir))
  end

  defp find_matching_po(pot_file, po_dir) do
    domain = Path.basename(pot_file, ".pot")
    {pot_file, Path.join(po_dir, "#{domain}.po")}
  end

  defp merge_or_create({pot_file, po_file}) do
    if File.regular?(po_file) do
      {po_file, Merger.merge_files(po_file, pot_file)}
    else
      {po_file, Merger.new_po_file(po_file, pot_file)}
    end
  end

  defp write_file({path, contents}) do
    File.write!(path, contents)
    Mix.shell.info "Wrote #{path}"
  end

  defp po_has_matching_pot?(po_file, pot_dir) do
    domain = Path.basename(po_file, ".po")
    pot_path = Path.join(pot_dir, "#{domain}.pot")
    File.exists?(pot_path)
  end

  defp warn_for_missing_pot_file(po_file, pot_dir) do
    Mix.shell.info "Warning: PO file #{po_file} has no matching POT file in #{pot_dir}"
  end

  defp ensure_file_exists!(path) do
    unless File.regular?(path), do: Mix.raise("No such file: #{path}")
  end

  defp ensure_dir_exists!(path) do
    unless File.dir?(path), do: Mix.raise("No such directory: #{path}")
  end
end
