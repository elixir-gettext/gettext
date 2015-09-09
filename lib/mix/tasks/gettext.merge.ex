defmodule Mix.Tasks.Gettext.Merge do
  use Mix.Task
  @recursive true

  @shortdoc "Merges .pot files into existing .po files"

  @doc """
  """
  def run(_args, priv_dir \\ "priv") do
    _ = Mix.Project.get!

    written_files =
      priv_dir
      |> Path.join("**/*.po")
      |> Path.wildcard()
      |> Enum.group_by(&priv_prefix/1)
      |> Map.delete(:not_in_canonical_dir)
      |> make_po_paths_relative_to_respective_root
      |> Enum.flat_map(&merge_dir/1)
      |> Enum.map(&write_file/1)

    Enum.each written_files, fn path ->
      Mix.shell.info "Wrote #{path}"
    end

    if written_files == [], do: :noop, else: :ok
  end

  defp priv_prefix(path) do
    parts = Path.split(path)

    if index = Enum.find_index(parts, &match?("LC_MESSAGES", &1)) do
      parts |> Enum.take(index - 1) |> Path.join
    else
      :not_in_canonical_dir
    end
  end

  defp make_po_paths_relative_to_respective_root(paths) do
    for {root, po_paths} <- paths, into: %{} do
      root_length = String.length(root)
      po_paths = Enum.map po_paths, &String.slice(&1, (root_length + 1)..-1)
      {root, po_paths}
    end
  end

  defp merge_dir({root, po_files}) do
    Enum.map(po_files, &merge_po_file(root, &1))
  end

  defp merge_po_file(root, po_file) do
    pot_file = po_path_to_pot_path(po_file, root)
    po_file = Path.join(root, po_file)

    po = Gettext.PO.parse_file!(po_file)

    merged =
      if File.exists?(pot_file) do
        pot = Gettext.PO.parse_file!(pot_file)
        Gettext.PO.merge(po, pot, pot_onto_po: true)
      else
        po
      end

    {po_file, Gettext.PO.dump(merged)}
  end

  defp write_file({path, contents}) do
    File.write!(path, contents)
    path
  end

  defp po_path_to_pot_path(po_file, root) do
    domain = Path.basename(po_file, ".po")
    Path.join(root, "#{domain}.pot")
  end
end
