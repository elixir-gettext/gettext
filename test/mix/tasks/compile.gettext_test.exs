defmodule Mix.Tasks.Compile.GettextTest do
  use ExUnit.Case, async: true

  @po_path "../../../tmp/gettext" |> Path.expand(__DIR__) |> Path.relative_to_cwd()

  defmodule MyProject do
    def project do
      [
        app: :my_project,
        gettext: [compiler_po_wildcard: "**/*.po"]
      ]
    end
  end

  setup do
    Mix.Project.push(MyProject)
    File.rm_rf!(@po_path)
    File.rm_rf!(Path.join(Mix.Project.app_path(), ".compile_tmp_gettext_foo"))

    on_exit(fn ->
      Mix.Project.pop()
    end)

    :ok
  end

  test "touches manifest file when necessary" do
    assert read_manifest(".compile_tmp_gettext_foo") == []
    assert run([]) == {:noop, []}
    assert read_manifest(".compile_tmp_gettext_foo") == []

    # Write .po file out of place
    write_po("hello.po")
    assert run([]) == {:noop, []}
    assert read_manifest(".compile_tmp_gettext_foo") == []

    # Write proper .po file
    write_po("foo/en/LC_MESSAGES/hello.po")
    assert run([]) == {:ok, []}

    assert read_manifest(".compile_tmp_gettext_foo") ==
             ["tmp/gettext/foo/en/LC_MESSAGES/hello.po"]

    # Write another .po file
    write_po("foo/en/LC_MESSAGES/world.po")
    assert run([]) == {:ok, []}

    assert read_manifest(".compile_tmp_gettext_foo") ==
             [
               "tmp/gettext/foo/en/LC_MESSAGES/hello.po",
               "tmp/gettext/foo/en/LC_MESSAGES/world.po"
             ]

    # Remove .po file
    remove_po("foo/en/LC_MESSAGES/world.po")
    assert run([]) == {:ok, []}

    assert read_manifest(".compile_tmp_gettext_foo") ==
             ["tmp/gettext/foo/en/LC_MESSAGES/hello.po"]

    # Write .po file to another directory
    write_po("bar/en/LC_MESSAGES/world.po")
    assert run([]) == {:ok, []}

    assert read_manifest(".compile_tmp_gettext_foo") ==
             ["tmp/gettext/foo/en/LC_MESSAGES/hello.po"]

    # Touch existing .po file
    touch_po("foo/en/LC_MESSAGES/hello.po")
    assert run([]) == {:ok, []}

    assert read_manifest(".compile_tmp_gettext_foo") ==
             ["tmp/gettext/foo/en/LC_MESSAGES/hello.po"]
  end

  defp run(args) do
    Mix.Tasks.Compile.Gettext.run(args, @po_path)
  end

  defp read_manifest(path) do
    case File.read(Path.join(Mix.Project.app_path(), path)) do
      {:ok, pos} -> String.split(pos, "\n", trim: true)
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
    File.rm!(Path.join(@po_path, path))
  end

  defp write_po(path) do
    path = Path.join(@po_path, path)
    File.mkdir_p!(Path.dirname(path))

    File.write!(path, """
    msgid "hello"
    msgstr "hello"
    """)
  end
end
