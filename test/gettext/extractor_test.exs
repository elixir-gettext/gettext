defmodule Gettext.ExtractorTest do
  use ExUnit.Case
  alias Gettext.Extractor

  defmodule MyGettext do
    use Gettext, otp_app: :test_application
  end

  defmodule MyOtherGettext do
    use Gettext, otp_app: :test_application, priv: "translations"
  end

  test "extraction process" do
    refute Extractor.extracting?
    Extractor.setup
    assert Extractor.extracting?

    code = """
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
        #: foo.ex:6
        #: foo.ex:8
        msgid "foo"
        msgstr ""
        """},

      {"priv/gettext/errors.pot",
          """
          #: foo.ex:7
          msgid "one error"
          msgid_plural "%{count} errors"
          msgstr[0] ""
          msgstr[1] ""
          """},

      {"translations/greetings.pot",
          """
          #: foo.ex:9
          msgid "hi"
          msgstr ""
          """}
    ]

    dumped = Enum.map(Extractor.dump_pot, fn {k, v} -> {k, IO.iodata_to_binary(v)} end)
    assert dumped == expected
    refute Extractor.extracting?
  end
end
