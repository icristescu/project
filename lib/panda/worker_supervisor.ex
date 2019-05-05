defmodule Panda.WorkerSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Logger.debug "WorkerSupervisor started..."
    DynamicSupervisor.init(strategy: :one_for_one, restart: :transient)
  end

end
