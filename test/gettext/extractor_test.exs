defmodule Gettext.ExtractorTest do
  use ExUnit.Case

  alias Gettext.Extractor
  alias Gettext.ExtractorAgent
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  defmodule MyGettext do
    use Gettext, otp_app: :test_application
  end

  defmodule MyOtherGettext do
    use Gettext, otp_app: :test_application, priv: "translations"
  end

  test "extraction process" do
    refute Extractor.extracting?
    Extractor.setup_for_extraction
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

    expected = %{
      MyGettext => %{
        "default" => %{
          "foo" => %Translation{
            msgid: ["foo"],
            msgstr: [""],
            references: [{"foo.ex", 6}, {"foo.ex", 8}],
          },
        },
        "errors" => %{
          {"one error", "%{count} errors"} => %PluralTranslation{
            msgid: ["one error"],
            msgid_plural: ["%{count} errors"],
            msgstr: %{0 => [""], 1 => [""]},
            references: [{"foo.ex", 7}],
          },
        },
      },
      MyOtherGettext => %{
        "greetings" => %{
          "hi" => %Translation{
            msgid: ["hi"],
            msgstr: [""],
            references: [{"foo.ex", 9}]
          },
        },
      },
    }

    assert ExtractorAgent.get_all == expected
  end
end
