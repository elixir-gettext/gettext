defmodule GettextTest.MixProjectHelpers do
  # Returns a module name segment that is unique per test. Tests in this suite
  # run in the same VM and reuse fixture module names; because
  # `Mix.Project.in_project/4` is called with `prune_code_paths: false`, every
  # test's compiled fixtures stay in the code path. Reusing a module name across
  # tests would let an earlier test's stale beam shadow the freshly compiled one,
  # so we derive a unique base module name from the test name instead.
  def unique_module(test) do
    "MyApp" <> Integer.to_string(:erlang.phash2(test))
  end

  def create_test_mix_file(context, gettext_config \\ []) do
    write_file(context, "mix.exs", """
    defmodule MyApp.MixProject do
      use Mix.Project

      def project() do
        [app: #{inspect(context.test)}, version: "0.1.0", gettext: #{inspect(gettext_config)}]
      end

      def application() do
        [extra_applications: [:logger, :gettext]]
      end
    end
    """)
  end

  def write_file(context, path, contents) do
    path = Path.join(context.tmp_dir, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  def read_file(context, path) do
    context.tmp_dir |> Path.join(path) |> File.read!()
  end

  def in_project(module, dir, fun) do
    Mix.Project.in_project(module, dir, [prune_code_paths: false], fun)
  end
end
