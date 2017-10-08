defmodule Gettext.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [Supervisor.Spec.worker(Gettext.ExtractorAgent, [])]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
