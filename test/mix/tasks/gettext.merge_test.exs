defmodule Mix.Tasks.Gettext.MergeTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  @priv_path "../../../tmp/gettext.merge" |> Path.expand(__DIR__) |> Path.relative_to_cwd()

  setup do
    File.rm_rf!(@priv_path)
    :ok
  end

  test "raises an error when if one of the files doesn't exist" do
    assert_raise Mix.Error, "No such file: foo.po", fn ->
      run(~w(foo.po bar.pot))
    end
  end

  test "raises an error if the files aren't a .po file and a .pot file" do
    assert_raise Mix.Error, "Arguments must be a PO file and a PO/POT file", fn ->
      run(~w(foo.ex bar.exs))
    end
  end

  test "passing more than one argument raises an error" do
    assert_raise Mix.Error, ~r/^You can only pass one or two arguments/, fn ->
      run(~w(foo bar baz bong))
    end
  end

  test "passing no arguments raises an error" do
    assert_raise Mix.Error, ~r/You can only pass one or two arguments/, fn ->
      run([])
    end
  end

  test "passing a :fuzzy_threshold outside of 0..1 raises an error" do
    File.mkdir_p!(@priv_path)

    assert_raise Mix.Error, "The :fuzzy_threshold option must be a float >= 0.0 and <= 1.0", fn ->
      run([@priv_path, "--fuzzy-threshold", "5.0"])
    end
  end

  test "merging an existing PO file with a new POT file" do
    pot_contents = """
    msgid "hello"
    msgstr ""
    """

    write_file("foo.pot", pot_contents)

    write_file("it/LC_MESSAGES/foo.po", "")

    output =
      capture_io(fn ->
        run([tmp_path("it/LC_MESSAGES/foo.po"), tmp_path("foo.pot")])
      end)

    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/foo.po"

    assert output =~
             "(1 new message, 0 removed, 0 unchanged, 0 reworded (fuzzy), 0 marked as obsolete)"

    # The POT file is left unchanged
    assert read_file("foo.pot") == pot_contents

    assert read_file("it/LC_MESSAGES/foo.po") == """
           msgid "hello"
           msgstr ""
           """
  end

  test "marks messages as obsolete" do
    write_file("foo.pot", "")

    write_file("it/LC_MESSAGES/foo.po", """
    msgid "foo"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([
          tmp_path("it/LC_MESSAGES/foo.po"),
          tmp_path("foo.pot"),
          "--on-obsolete",
          "mark_as_obsolete"
        ])
      end)

    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/foo.po"

    assert output =~
             "(0 new messages, 0 removed, 0 unchanged, 0 reworded (fuzzy), 1 marked as obsolete)"
  end

  test "removes obsolete messages" do
    write_file("foo.pot", "")

    write_file("it/LC_MESSAGES/foo.po", """
    msgid "foo"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([tmp_path("it/LC_MESSAGES/foo.po"), tmp_path("foo.pot"), "--on-obsolete", "delete"])
      end)

    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/foo.po"

    assert output =~
             "(0 new messages, 1 removed, 0 unchanged, 0 reworded (fuzzy), 0 marked as obsolete)"
  end

  test "validates on-obsolete" do
    write_file("foo.pot", "")
    write_file("it/LC_MESSAGES/foo.po", "")

    expected_message = """
    An invalid value was provided for the option `on_obsolete`.
    Value: "invalid"
    Valid Choices: "delete" / "mark_as_obsolete"
    """

    assert_raise Mix.Error, expected_message, fn ->
      run([tmp_path("it/LC_MESSAGES/foo.po"), tmp_path("foo.pot"), "--on-obsolete", "invalid"])
    end
  end

  test "passing a dir and a --locale opt will update/create PO files in the locale dir" do
    write_file("default.pot", """
    msgid "def"
    msgstr ""
    """)

    write_file("new.pot", """
    msgid "new"
    msgstr ""
    """)

    write_file("it/LC_MESSAGES/default.po", "")

    output =
      capture_io(fn ->
        run([@priv_path, "--locale", "it"])
      end)

    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/new.po"
    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/default.po"

    assert read_file("it/LC_MESSAGES/default.po") == """
           msgid "def"
           msgstr ""
           """

    new_po = read_file("it/LC_MESSAGES/new.po")

    assert new_po =~ ~S"""
           msgid ""
           msgstr ""
           "Language: it\n"
           "Plural-Forms: nplurals=2\n"

           msgid "new"
           msgstr ""
           """

    assert String.starts_with?(new_po, "## \"msgid\"s in this file come from POT")
  end

  test "enabling --store-previous-message-on-fuzzy-match stores previous message" do
    write_file("default.pot", """
    msgid "Hello Worlds"
    msgstr ""
    """)

    write_file("it/LC_MESSAGES/default.po", """
    msgid "Hello World"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([@priv_path, "--locale", "it", "--store-previous-message-on-fuzzy-match"])
      end)

    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/default.po"

    assert read_file("it/LC_MESSAGES/default.po") == """
           #, fuzzy
           #| msgid "Hello World"
           msgid "Hello Worlds"
           msgstr ""
           """
  end

  test "passing a dir and a --locale opt will update/create PO files in the locale dir with custom plural forms" do
    write_file("new.pot", """
    msgid "new"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([@priv_path, "--locale", "it", "--plural-forms-header", "nplurals=3"])
      end)

    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/new.po"
    new_po = read_file("it/LC_MESSAGES/new.po")

    assert new_po =~ ~S"""
           msgid ""
           msgstr ""
           "Language: it\n"
           "Plural-Forms: nplurals=3\n"

           msgid "new"
           msgstr ""
           """
  end

  test "passing a dir and a --locale opt will update/create PO files in the locale dir with app env plural forms" do
    Application.put_env(:gettext, :plural_forms, GettextTest.CustomPlural)

    write_file("new.pot", """
    msgid "new"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([@priv_path, "--locale", "elv"])
      end)

    assert output =~ "Wrote tmp/gettext.merge/elv/LC_MESSAGES/new.po"
    new_po = read_file("elv/LC_MESSAGES/new.po")

    assert new_po =~ ~S"""
           msgid ""
           msgstr ""
           "Language: elv\n"
           "Plural-Forms: nplurals=2\n"

           msgid "new"
           msgstr ""
           """
  after
    Application.put_env(:gettext, :plural_forms, Gettext.Plural)
  end

  test "passing just a dir merges with PO files in every locale" do
    write_file("fr/LC_MESSAGES/foo.po", "")
    write_file("it/LC_MESSAGES/foo.po", "")

    contents = """
    msgid "foo"
    msgstr ""
    """

    write_file("foo.pot", contents)

    output =
      capture_io(fn ->
        run([@priv_path])
      end)

    assert output =~ "Wrote tmp/gettext.merge/fr/LC_MESSAGES/foo.po"
    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/foo.po"

    assert read_file("fr/LC_MESSAGES/foo.po") == contents
    assert read_file("it/LC_MESSAGES/foo.po") == contents
  end

  test "non existing locale/LC_MESSAGES directories are created" do
    write_file("foo.pot", """
    msgid "foo"
    msgstr ""
    """)

    created_dir = Path.join([@priv_path, "en", "LC_MESSAGES"])

    refute File.dir?(created_dir)

    output =
      capture_io(fn ->
        run([@priv_path, "--locale", "en"])
      end)

    assert File.dir?(created_dir)
    assert output =~ "Created directory #{created_dir}"
  end

  test "informative comments at the top of the file" do
    write_file("inf.pot", """
    msgid "foo"
    msgstr ""
    """)

    capture_io(fn ->
      run([@priv_path, "--locale", "en"])
      contents = read_file("en/LC_MESSAGES/inf.po")
      assert contents =~ "## \"msgid\"s in this file"

      # Running the task again without having change the PO file shouldn't
      # remove the informative comment.
      run([@priv_path, "--locale", "en"])
      assert contents == read_file("en/LC_MESSAGES/inf.po")
    end)
  end

  defp write_file(path, contents) do
    path = tmp_path(path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  defp read_file(path) do
    path |> tmp_path() |> File.read!()
  end

  defp tmp_path(path) do
    Path.join(@priv_path, path)
  end

  defp run(args) do
    Mix.Tasks.Gettext.Merge.run(args)
  end
end
