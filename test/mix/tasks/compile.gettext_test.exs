defmodule Mix.Tasks.Compile.GettextTest do
  use ExUnit.Case, async: true

  @po_path "../../../tmp/compile.gettext" |> Path.expand(__DIR__) |> Path.relative_to_cwd
  @manifest_path Application.app_dir(:gettext, @po_path)

  setup do
    File.rm_rf!(@po_path)
    File.rm_rf!(@manifest_path)
    :ok
  end

  test "touches manifest file when necessary" do
    assert read_manifest("foo/.compile.gettext") == []
    assert run([]) == :noop
    assert read_manifest("foo/.compile.gettext") == []

    # Write .po file out of place
    write_po "hello.po"
    assert run([]) == :noop
    assert read_manifest("foo/.compile.gettext") == []

    # Write proper .po file
    write_po "foo/en/LC_MESSAGES/hello.po"
    assert run([]) == :ok
    assert read_manifest("foo/.compile.gettext") ==
           ["tmp/compile.gettext/foo/en/LC_MESSAGES/hello.po"]

    # Write another .po file
    write_po "foo/en/LC_MESSAGES/world.po"
    assert run([]) == :ok
    assert read_manifest("foo/.compile.gettext") ==
           ["tmp/compile.gettext/foo/en/LC_MESSAGES/hello.po",
            "tmp/compile.gettext/foo/en/LC_MESSAGES/world.po"]

    # Remove .po file
    remove_po "foo/en/LC_MESSAGES/world.po"
    assert run([]) == :ok
    assert read_manifest("foo/.compile.gettext") ==
           ["tmp/compile.gettext/foo/en/LC_MESSAGES/hello.po"]

    # Write .po file to another directory
    write_po "bar/en/LC_MESSAGES/world.po"
    assert run([]) == :ok
    assert read_manifest("foo/.compile.gettext") ==
           ["tmp/compile.gettext/foo/en/LC_MESSAGES/hello.po"]

    # Touch existing .po file
    touch_po "foo/en/LC_MESSAGES/hello.po"
    assert run([]) == :ok
    assert read_manifest("foo/.compile.gettext") ==
           ["tmp/compile.gettext/foo/en/LC_MESSAGES/hello.po"]
  end

  defp run(args) do
    Mix.Tasks.Compile.Gettext.run args, @po_path
  end

  defp read_manifest(path) do
    case File.read(Path.join(@manifest_path, path)) do
      {:ok, pos}  -> String.split(pos, "\n", trim: true)
      {:error, _} -> []
    end
  end

  defp touch_po(path) do
    path = Path.join(@po_path, path)
    touch_po(path, File.stat!(path).mtime)
  end

  defp touch_po(path, current) do
    File.touch!(path)
    unless File.stat!(path).mtime > current do
      touch_po(path, current)
    end
  end

  defp remove_po(path) do
    File.rm! Path.join(@po_path, path)
  end

  defp write_po(path) do
    path = Path.join(@po_path, path)
    File.mkdir_p! Path.dirname(path)
    File.write! path, """
    msgid "hello"
    msgstr "hello"
    """
  end
end
