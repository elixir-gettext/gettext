defmodule Mix.Tasks.Gettext.MergeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @priv_path "../../../tmp/gettext.merge" |> Path.expand(__DIR__) |> Path.relative_to_cwd

  setup do
    File.rm_rf!(@priv_path)
    :ok
  end

  test "updates existing .po files with their respective .pot file" do
    # Reference .pot file with a translation that is not in the .po file yet.
    write_file "default.pot", """
    msgid "hello"
    msgstr ""

    msgid "world"
    msgstr ""
    """

    write_file "it/LC_MESSAGES/default.po", """
    msgid "hello"
    msgstr "ciao"
    """

    # This .po file has no matching .pot file, so it's left untouched.
    nomatch_contents = """
    msgid "text"
    msgstr "testo"
    """
    write_file "it/LC_MESSAGES/nomatch.po", nomatch_contents

    output = capture_io fn ->
      Mix.Tasks.Gettext.Merge.run([], @priv_path)
    end

    assert output =~ "Wrote #{Path.join(@priv_path, "it/LC_MESSAGES/nomatch.po")}"
    assert output =~ "Wrote #{Path.join(@priv_path, "it/LC_MESSAGES/default.po")}"

    assert read_file("it/LC_MESSAGES/default.po") == """
    msgid "hello"
    msgstr "ciao"

    msgid "world"
    msgstr ""
    """

    assert read_file("it/LC_MESSAGES/nomatch.po") == nomatch_contents
  end

  defp write_file(path, contents) do
    path = Path.join(@priv_path, path)
    File.mkdir_p! Path.dirname(path)
    File.write!(path, contents)
  end

  defp read_file(path) do
    File.read! Path.join(@priv_path, path)
  end
end
