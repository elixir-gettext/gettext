#!/usr/bin/env elixir

Mix.install([
  {:gettext, path: "."},
  {:expo, "~> 1.0"},
  {:large_translations_catalogue,
   github: "jshmrtn/hygeia",
   branch: "main",
   app: false,
   compile: false,
   depth: 1,
   sparse: "priv/gettext"},
  {:benchee, "~> 1.3"}
])

require Logger

catalogue_base_path =
  Path.join([Mix.install_project_dir(), "deps", "large_translations_catalogue", "priv", "gettext"])

Logger.info("Preparing .mo files")

po_files = Path.wildcard(Path.join([catalogue_base_path, "*", "LC_MESSAGES", "*.po"]))

for path <- po_files do
  mo_path = Path.rootname(path, ".po") <> ".mo"
  Mix.Task.rerun("expo.msgfmt", [path, "--output-file", mo_path])
end

mo_files = Path.wildcard(Path.join([catalogue_base_path, "*", "LC_MESSAGES", "*.mo"]))

Logger.info("Performance Test Expo Parse")

Benchee.run(
  [
    expo_po_parse: fn ->
      for file <- po_files, do: Expo.PO.parse_file!(file)
    end,
    expo_mo_parse: fn ->
      for file <- mo_files, do: Expo.MO.parse_file!(file)
    end
  ],
  warmup: 5,
  time: 60,
  memory_time: 2,
  parallel: System.schedulers_online()
)

Logger.info("Performance Test Gettext Backend Compile")

Benchee.run(
  [
    gettext_po_compile: fn ->
      name = make_ref() |> inspect() |> String.to_atom()

      defmodule name do
        use Gettext.Backend, otp_app: :gettext, priv: catalogue_base_path
      end
    end,
    gettext_mo_compile: fn ->
      name = make_ref() |> inspect() |> String.to_atom()

      defmodule name do
        use Gettext.Backend, otp_app: :gettext, priv: catalogue_base_path, type: :mo
      end
    end
  ],
  warmup: 5,
  time: 60,
  memory_time: 2,
  parallel: System.schedulers_online()
)
