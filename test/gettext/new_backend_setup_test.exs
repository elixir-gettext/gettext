defmodule Gettext.NewBackendSetupTest do
  # https://github.com/elixir-gettext/gettext/issues/330
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import GettextTest.MixProjectHelpers

  @moduletag :tmp_dir

  defmodule Backend do
    use Gettext.Backend, otp_app: :test_application
  end

  describe "use Gettext, backend: ..." do
    test "imports Gettext.Macros macros but doesn't generate functions" do
      {{:module, mod, _bytecode, _funs}, _bindings} =
        Code.eval_quoted(
          quote do
            defmodule MyModule do
              use Gettext,
                backend: Gettext.NewBackendSetupTest.Backend

              def translate do
                gettext("Hello world")
              end
            end
          end
        )

      refute function_exported?(mod, :__gettext__, 1)

      assert mod.translate() == "Hello world"
    end
  end

  describe "compile-time dependencies" do
    @tag :skip
    test "are not created for modules that use the backend",
         %{test: test, tmp_dir: tmp_dir} = context do
      create_test_mix_file(context)

      write_file(context, "lib/my_app.ex", """
      defmodule MyApp.Gettext do
        use Gettext.Backend, otp_app: #{inspect(test)}
      end

      defmodule MyApp do
        use Gettext, backend: MyApp.Gettext
      end
      """)

      output =
        in_project(test, tmp_dir, fn _module ->
          capture_io(fn -> Mix.Task.run("compile") end)
          capture_io(fn -> Mix.Task.run("xref", ["trace", "lib/my_app.ex"]) end)
        end)

      assert output =~ ~r"lib/my_app\.ex:\d+: alias MyApp\.Gettext \(runtime\)\n"
      refute output =~ ~r"lib/my_app\.ex:\d+: alias MyApp\.Gettext \(compile\)\n"
    end
  end
end
