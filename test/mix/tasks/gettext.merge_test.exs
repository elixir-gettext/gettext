defmodule Mix.Tasks.Gettext.MergeTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

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

  @tag :tmp_dir
  test "passing a :fuzzy_threshold outside of 0..1 raises an error", %{tmp_dir: tmp_dir} do
    File.mkdir_p(tmp_dir)

    assert_raise Mix.Error, "The :fuzzy_threshold option must be a float >= 0.0 and <= 1.0", fn ->
      run([tmp_dir, "--fuzzy-threshold", "5.0"])
    end
  end

  @tag :tmp_dir
  test "merging an existing PO file with a new POT file", %{tmp_dir: tmp_dir} do
    pot_contents = """
    msgid "hello"
    msgstr ""
    """

    write_file(Path.join(tmp_dir, "foo.pot"), pot_contents)

    write_file(Path.join(tmp_dir, "it/LC_MESSAGES/foo.po"), "")

    output =
      capture_io(fn ->
        run([Path.join(tmp_dir, "it/LC_MESSAGES/foo.po"), Path.join(tmp_dir, "foo.pot")])
      end)

    assert output =~ ~r{Wrote .*/it/LC_MESSAGES/foo\.po}

    assert output =~
             "(1 new message, 0 removed, 0 unchanged, 0 reworded (fuzzy), 0 marked as obsolete)"

    # The POT file is left unchanged
    assert File.read!(Path.join(tmp_dir, "foo.pot")) == pot_contents

    assert File.read!(Path.join(tmp_dir, "it/LC_MESSAGES/foo.po")) == """
           msgid "hello"
           msgstr ""
           """
  end

  @tag :tmp_dir
  test "marks messages as obsolete", %{tmp_dir: tmp_dir} do
    write_file(Path.join(tmp_dir, "foo.pot"), "")

    write_file(Path.join(tmp_dir, "it/LC_MESSAGES/foo.po"), """
    msgid "foo"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([
          Path.join(tmp_dir, "it/LC_MESSAGES/foo.po"),
          Path.join(tmp_dir, "foo.pot"),
          "--on-obsolete",
          "mark_as_obsolete"
        ])
      end)

    assert output =~ ~r{Wrote .*/it/LC_MESSAGES/foo.po}

    assert output =~
             "(0 new messages, 0 removed, 0 unchanged, 0 reworded (fuzzy), 1 marked as obsolete)"
  end

  @tag :tmp_dir
  test "removes obsolete messages", %{tmp_dir: tmp_dir} do
    write_file(Path.join(tmp_dir, "foo.pot"), "")

    write_file(Path.join(tmp_dir, "it/LC_MESSAGES/foo.po"), """
    msgid "foo"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([
          Path.join(tmp_dir, "it/LC_MESSAGES/foo.po"),
          Path.join(tmp_dir, "foo.pot"),
          "--on-obsolete",
          "delete"
        ])
      end)

    assert output =~ ~r{Wrote .*/it/LC_MESSAGES/foo.po}

    assert output =~
             "(0 new messages, 1 removed, 0 unchanged, 0 reworded (fuzzy), 0 marked as obsolete)"
  end

  @tag :tmp_dir
  test "validates on-obsolete", %{tmp_dir: tmp_dir} do
    write_file(Path.join(tmp_dir, "foo.pot"), "")
    write_file(Path.join(tmp_dir, "it/LC_MESSAGES/foo.po"), "")

    expected_message = """
    An invalid value was provided for the option `on_obsolete`.
    Value: "invalid"
    Valid Choices: "delete" / "mark_as_obsolete"
    """

    assert_raise Mix.Error, expected_message, fn ->
      run([
        Path.join(tmp_dir, "it/LC_MESSAGES/foo.po"),
        Path.join(tmp_dir, "foo.pot"),
        "--on-obsolete",
        "invalid"
      ])
    end
  end

  @tag :tmp_dir
  test "passing a dir and a --locale opt will update/create PO files in the locale dir",
       %{tmp_dir: tmp_dir} do
    write_file(Path.join(tmp_dir, "default.pot"), """
    msgid "def"
    msgstr ""
    """)

    write_file(Path.join(tmp_dir, "new.pot"), """
    msgid "new"
    msgstr ""
    """)

    write_file(Path.join(tmp_dir, "it/LC_MESSAGES/default.po"), "")

    output =
      capture_io(fn ->
        run([tmp_dir, "--locale", "it"])
      end)

    assert output =~ ~r{Wrote .*/it/LC_MESSAGES/new.po}
    assert output =~ ~r{Wrote .*/it/LC_MESSAGES/default.po}

    assert File.read!(Path.join(tmp_dir, "it/LC_MESSAGES/default.po")) == """
           msgid "def"
           msgstr ""
           """

    new_po = File.read!(Path.join(tmp_dir, "it/LC_MESSAGES/new.po"))

    assert new_po =~ ~S"""
           msgid ""
           msgstr ""
           "Language: it\n"
           "Plural-Forms: nplurals=2; plural=(n != 1);\n"

           msgid "new"
           msgstr ""
           """

    assert String.starts_with?(new_po, "## \"msgid\"s in this file come from POT")
  end

  @tag :tmp_dir
  test "enabling --store-previous-message-on-fuzzy-match stores previous message",
       %{tmp_dir: tmp_dir} do
    write_file(Path.join(tmp_dir, "default.pot"), """
    msgid "Hello Worlds"
    msgstr ""
    """)

    write_file(Path.join(tmp_dir, "it/LC_MESSAGES/default.po"), """
    msgid "Hello World"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([tmp_dir, "--locale", "it", "--store-previous-message-on-fuzzy-match"])
      end)

    assert output =~ ~r{Wrote .*/it/LC_MESSAGES/default.po}

    assert File.read!(Path.join(tmp_dir, "it/LC_MESSAGES/default.po")) == """
           #, fuzzy
           #| msgid "Hello World"
           msgid "Hello Worlds"
           msgstr ""
           """
  end

  @tag :tmp_dir
  test "passing a dir and a --locale opt will update/create PO files in the locale dir with custom plural forms",
       %{tmp_dir: tmp_dir} do
    write_file(Path.join(tmp_dir, "new.pot"), """
    msgid "new"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([
          tmp_dir,
          "--locale",
          "it",
          "--plural-forms-header",
          "nplurals=3; plural=n==0 ? 0 : n > 1;"
        ])
      end)

    assert output =~ ~r{Wrote .*/it/LC_MESSAGES/new.po}

    assert File.read!(Path.join(tmp_dir, "it/LC_MESSAGES/new.po")) =~ ~S"""
           msgid ""
           msgstr ""
           "Language: it\n"
           "Plural-Forms: nplurals=3; plural=n==0 ? 0 : n > 1;\n"

           msgid "new"
           msgstr ""
           """
  end

  @tag :tmp_dir
  test "passing a dir and a --locale opt will update/create PO files in the locale dir with app env plural forms",
       %{tmp_dir: tmp_dir} do
    Application.put_env(:gettext, :plural_forms, GettextTest.CustomPlural)

    write_file(Path.join(tmp_dir, "new.pot"), """
    msgid "new"
    msgstr ""
    """)

    output =
      capture_io(fn ->
        run([tmp_dir, "--locale", "elv"])
      end)

    assert output =~ ~r{Wrote .*/elv/LC_MESSAGES/new.po}

    assert File.read!(Path.join(tmp_dir, "elv/LC_MESSAGES/new.po")) =~ ~S"""
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

  @tag :tmp_dir
  test "passing just a dir merges with PO files in every locale", %{tmp_dir: tmp_dir} do
    write_file(Path.join(tmp_dir, "fr/LC_MESSAGES/foo.po"), "")
    write_file(Path.join(tmp_dir, "it/LC_MESSAGES/foo.po"), "")

    contents = """
    msgid "foo"
    msgstr ""
    """

    write_file(Path.join(tmp_dir, "foo.pot"), contents)

    output = capture_io(fn -> run([tmp_dir]) end)

    assert output =~ ~r{Wrote .*/fr/LC_MESSAGES/foo.po}
    assert output =~ ~r{Wrote .*/it/LC_MESSAGES/foo.po}

    assert File.read!(Path.join(tmp_dir, "fr/LC_MESSAGES/foo.po")) == contents
    assert File.read!(Path.join(tmp_dir, "it/LC_MESSAGES/foo.po")) == contents
  end

  @tag :tmp_dir
  test "non-existing locale/LC_MESSAGES directories are created", %{tmp_dir: tmp_dir} do
    write_file(Path.join(tmp_dir, "foo.pot"), """
    msgid "foo"
    msgstr ""
    """)

    created_dir = Path.join([tmp_dir, "en", "LC_MESSAGES"])

    refute File.dir?(created_dir)

    output =
      capture_io(fn ->
        run([tmp_dir, "--locale", "en"])
      end)

    assert File.dir?(created_dir)
    assert output =~ "Created directory #{created_dir}"
  end

  @tag :tmp_dir
  test "informative comments at the top of the file", %{tmp_dir: tmp_dir} do
    write_file(Path.join(tmp_dir, "inf.pot"), """
    msgid "foo"
    msgstr ""
    """)

    capture_io(:stdio, fn ->
      capture_io(:stderr, fn ->
        run([tmp_dir, "--locale", "en"])
        contents = File.read!(Path.join(tmp_dir, "en/LC_MESSAGES/inf.po"))
        assert contents =~ "## \"msgid\"s in this file"

        # Running the task again without having change the PO file shouldn't
        # remove the informative comment.
        run([tmp_dir, "--locale", "en"])
        assert contents == File.read!(Path.join(tmp_dir, "en/LC_MESSAGES/inf.po"))
      end)
    end)
  end

  defp write_file(path, contents) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  defp run(args) do
    Mix.Tasks.Gettext.Merge.run(args)
  end
end
