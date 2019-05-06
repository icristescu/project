defmodule Panda.Server do
  @moduledoc """
  Handles the application calls :upcoming_matches and :odds_for_match.
  It creates workers for each API call.
  """
  use GenServer
  require Logger

  defmodule State do
    defstruct results: [], # store results from workers as they come
      matches: nil,        # upcoming matches
      scores: nil,         # cache for previously computed results
      rating_system: nil,  # :norm for now
      application_ref: nil # reply to Application once all results are in
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Logger.debug "Server started..."
    {:ok, %State{scores: new(:scores)}}
  end

  @doc """
  Starts a worker to call the panda api.
  It fetches results from the worker, formats the output in response
  and stores the result in State.
  It shutdown the worker.
  """
  def handle_call(:upcoming_matches, _from, state) do
    pid = init_child()
    Logger.debug "worker #{inspect pid} started"

    matches = GenServer.call(pid, :upcoming_matches, 10000)

    response = Enum.map(matches,
      fn match ->
	Map.put(%{}, "begin_at", match["begin_at"])
	|> Map.put("id", match["id"])
	|> Map.put("name", match["name"])
      end)

    Process.exit(pid, :shutdown)
    Logger.debug "worker #{inspect pid} shutdown"

    {:reply, response, %{state| matches: matches}}
  end

  @doc """
  Starts a worker for each player in the match to call the panda api and
  compute a score for that player.
  If match score is in the cache, then retrieve it and send it to Application.
  """
  def handle_call({:odds_for_match, match_id, rating_system}, from,
    state = %{matches: matches, scores: scores}) do

    state = %{state | rating_system: rating_system, application_ref: from}

    case check_args(matches, match_id) do
      {:error, msg} -> {:reply, msg, state}
      :ok ->
	case lookup(scores, match_id) do
	  {:ok, result} ->
	    Logger.debug "cached match #{match_id} is #{inspect result}"
	    GenServer.reply(from, result)
	  :error ->
	    start_workers(match_id, matches)
	end
	{:noreply, state}
    end
  end

  defp start_workers(match_id, matches) do

    Logger.debug "the players for match #{match_id} are"

    get_players(matches, match_id)
    |> Enum.each(fn player ->
      pid = init_child()

      Logger.debug (inspect player)
      Logger.debug "worker #{inspect pid} started"

      GenServer.cast(pid, {:odds_for_match, self(), player, match_id})
    end)
  end

  def check_args(matches, match_id) do
    if matches == nil do
      {:error, "please call Panda.upcoming_matches first"}
    else
      if Enum.find(matches, fn match -> match["id"] == match_id end) do :ok
      else {:error, "please provide a match id from the upcoming matches"}
      end
    end
  end

  @doc """
  Receives results from workers and shutdown workers.

  When all results are in, compute the final result.
  Stores the final result in cache and send it to Application.
  Cleans up the state and shutdown workers.
  """
  def handle_info({:reply, child_pid, player, match_id},
    state = %{matches: matches, results: results, scores: scores,
	      application_ref: reply_to, rating_system: rating_system}) do
    Logger.debug "receive #{inspect player} from #{inspect child_pid}"

    new_results = [player | results]
    nb_players = get_nb_players(matches, match_id)

    update_results_in_state =
    if (length(new_results) == nb_players) do

      result =
      if (rating_system == :norm) do
	Panda.Rating.normalise(new_results)
      else Panda.Rating.elo(new_results)
      end

      insert(scores, {match_id, result})
      GenServer.reply(reply_to, result)
      []
    else new_results
    end

    Process.exit(child_pid, :shutdown)
    Logger.debug "worker #{inspect child_pid} shutdown"

    {:noreply, %{state | results: update_results_in_state}}
  end

  def get_players(matches, match_id) do
    matches
    |> Enum.find(fn match -> match["id"] == match_id end)
    |> Map.get("opponents")
    |> Enum.map(fn player ->
      Map.put(%{}, "acronym", player["opponent"]["acronym"])
      |> Map.put("id", player["opponent"]["id"])
    end)
  end

  def get_nb_players(matches, match_id) do
    match = Enum.find(matches, fn match -> match["id"] == match_id end)
    Enum.count(match["opponents"])
  end

  defp init_child() do
    spec = Supervisor.child_spec({Panda.Worker, []},
      id: Panda.Worker, restart: :transient)
    {:ok, pid} = DynamicSupervisor.start_child(Panda.WorkerSupervisor, spec)
    pid
  end

  defp new(table) do
    :ets.new(table, [:set, :protected])
  end

  defp insert(table, {key, val}) do
    :ets.insert(table, {key, val})
  end

  defp lookup(table, key) do
    case :ets.lookup(table, key) do
      [{^key, val}] -> {:ok, val}
      [] -> :error
    end
  end

end
