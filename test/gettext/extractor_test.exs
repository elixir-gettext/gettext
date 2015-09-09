defmodule Gettext.ExtractorTest do
  use ExUnit.Case
  alias Gettext.Extractor
  alias Gettext.PO
  alias Gettext.PO.Translation

  @pot_path "../../tmp/" |> Path.expand(__DIR__) |> Path.relative_to_cwd

  test "merge_pot_files/2" do
    paths = %{
      tomerge: Path.join(@pot_path, "tomerge.pot"),
      ignored: Path.join(@pot_path, "ignored.pot"),
      new: Path.join(@pot_path, "new.pot"),
    }

    extracted_po_structs = [
      {paths.tomerge, %PO{translations: [%Translation{msgid: ["other"], msgstr: [""]}]}},
      {paths.new, %PO{translations: [%Translation{msgid: ["new"], msgstr: [""]}]}},
    ]

    write_file paths.tomerge, """
    msgid "foo"
    msgstr ""
    """

    write_file paths.ignored, """
    msgid "ignored"
    msgstr ""
    """

    structs = Extractor.merge_pot_files([paths.tomerge, paths.ignored], extracted_po_structs)

    {_, contents} = List.keyfind(structs, paths.ignored, 0)
    assert IO.iodata_to_binary(contents) == """
    msgid "ignored"
    msgstr ""
    """

    {_, contents} = List.keyfind(structs, paths.tomerge, 0)
    assert IO.iodata_to_binary(contents) == """
    msgid "foo"
    msgstr ""

    msgid "other"
    msgstr ""
    """

    {_, contents} = List.keyfind(structs, paths.new, 0)
    assert IO.iodata_to_binary(contents) == """
    msgid "new"
    msgstr ""
    """
  end

  test "extraction process" do
    refute Extractor.extracting?
    Extractor.setup
    assert Extractor.extracting?

    code = """
    defmodule Gettext.ExtractorTest.MyGettext do
      use Gettext, otp_app: :test_application
    end

    defmodule Gettext.ExtractorTest.MyOtherGettext do
      use Gettext, otp_app: :test_application, priv: "translations"
    end

    defmodule Foo do
      import Gettext.ExtractorTest.MyGettext
      require Gettext.ExtractorTest.MyOtherGettext

      def bar do
        gettext "foo"
        dngettext "errors", "one error", "%{count} errors", 2
        gettext "foo"
        Gettext.ExtractorTest.MyOtherGettext.dgettext "greetings", "hi"
      end
    end
    """

    Code.compile_string(code, Path.join(File.cwd!, "foo.ex"))

    expected = [
      {"priv/gettext/default.pot",
        """
        #: foo.ex:14
        #: foo.ex:16
        msgid "foo"
        msgstr ""
        """},

      {"priv/gettext/errors.pot",
          """
          #: foo.ex:15
          msgid "one error"
          msgid_plural "%{count} errors"
          msgstr[0] ""
          msgstr[1] ""
          """},

      {"translations/greetings.pot",
          """
          #: foo.ex:17
          msgid "hi"
          msgstr ""
          """}
    ]

    dumped = Enum.map(Extractor.dump_pot, fn {k, v} -> {k, IO.iodata_to_binary(v)} end)
    assert dumped == expected
    refute Extractor.extracting?
  end

  defp write_file(path, contents) do
    path |> Path.dirname |> File.mkdir_p!
    File.write!(path, contents)
  end
end
