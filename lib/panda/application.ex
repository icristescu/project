defmodule Panda.Application do
  use Application

  def start(_type, _args) do

    children = [
      # Starts a worker by calling: Panda.Worker.start_link(arg)
      {Panda.WorkerSupervisor, :ok},
      {Panda.Server, :ok}
    ]

    opts = [strategy: :one_for_one, name: Panda.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def upcoming_matches do
    GenServer.call(Panda.Server, :upcoming_matches, 10000)
  end

  def odds_for_match(match_id) do
    GenServer.call(Panda.Server, {:odds_for_match, match_id}, :infinity)
  end

end
