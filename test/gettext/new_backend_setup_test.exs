# https://github.com/elixir-gettext/gettext/issues/330
defmodule Gettext.NewBackendSetupTest do
  # Has to be async: false since it changes Elixir compiler options.
  use ExUnit.Case, async: false

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
    test "are not created for modules that use the backend", %{test: test} do
      top_level_module = :"Elixir.Gettext_#{test}"
      backend_module = Module.concat(top_level_module, Gettext)

      Code.eval_quoted(
        quote do
          defmodule unquote(backend_module) do
            use Gettext.Backend, otp_app: unquote(test)
          end
        end
      )

      old_compiler_opts = Code.compiler_options(tracers: [__MODULE__])
      on_exit(fn -> Code.compiler_options(old_compiler_opts) end)

      Code.compile_quoted(
        quote do
          defmodule unquote(top_level_module) do
            use Gettext, backend: unquote(backend_module)
          end
        end
      )

      refute_received {:trace, {:require, _meta, ^backend_module, _opts}}
      refute_received {:trace, {:import, _meta, ^backend_module, _opts}}
    end
  end

  def trace(event, _env) do
    send(self(), {:trace, event})
    :ok
  end
end
