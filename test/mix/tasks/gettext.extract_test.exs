defmodule Mix.Tasks.Gettext.ExtractTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  @priv_path "../../../tmp/gettext.extract" |> Path.expand(__DIR__) |> Path.relative_to_cwd()

  setup do
    File.rm_rf!(@priv_path)
    :ok
  end

  test "extracting and extracting with --merge" do
    write_file("mix.exs", """
    defmodule MyApp.MixProject do
      use Mix.Project

      def project() do
        [app: :my_app, version: "0.1.0"]
      end

      def application() do
        []
      end
    end
    """)

    write_file("lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext, otp_app: :my_app
    end

    defmodule MyApp do
      require MyApp.Gettext
      def foo(), do: MyApp.Gettext.gettext("hello")
    end
    """)

    output =
      capture_io(fn ->
        Mix.Project.in_project(:my_app, tmp_path("/"), fn _module -> run([]) end)
      end)

    assert output =~ "Extracted priv/gettext/default.pot"

    assert read_file("priv/gettext/default.pot") =~ """
           #, elixir-format
           #: lib/my_app.ex:7
           msgid "hello"
           msgstr ""
           """

    # Test --merge too.

    write_file("lib/other.ex", """
    defmodule MyApp.Other do
      require MyApp.Gettext
      def foo(), do: MyApp.Gettext.dgettext("my_domain", "other")
    end
    """)

    write_file("priv/gettext/it/LC_MESSAGES/my_domain.po", "")

    capture_io(fn ->
      Mix.Project.in_project(:my_app, tmp_path("/"), fn _module -> run(["--merge"]) end)
    end)

    assert read_file("priv/gettext/it/LC_MESSAGES/my_domain.po") == """
           #, elixir-format
           #: lib/other.ex:3
           msgid "other"
           msgstr ""
           """
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
    Mix.Tasks.Gettext.Extract.run(args)
  end
end
