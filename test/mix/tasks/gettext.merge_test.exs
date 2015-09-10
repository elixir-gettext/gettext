defmodule Mix.Tasks.Gettext.MergeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @priv_path "../../../tmp/gettext.merge" |> Path.expand(__DIR__) |> Path.relative_to_cwd

  setup do
    File.rm_rf!(@priv_path)
    :ok
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
