defmodule Panda.Server do
  @moduledoc """
  Handles the application calls :upcoming_matches and :odds_for_match.
  It creates workers for each API call.
  """
  use GenServer
  require Logger

  defmodule State do
    defstruct odds: [], # store results from workers as they come
      matches: nil,     # upcoming matches
      scores: nil       # cache for previously computed results
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

  def handle_call({:odds_for_match, match_id}, from,
    state = %{matches: matches, scores: scores}) do

    case check_args(matches, match_id) do
      {:error, msg} -> {:reply, msg, state}
      :ok ->
	handle_odds_for_match(match_id, from, matches, scores)
	{:noreply, state}
    end
  end

  @doc """
  Starts a worker for each player in the match to call the panda api and
  compute a score for that player.
  If player's score is in the cache, then retrieve it and send it to self.

  ## Parameters

  - match_id: id of the match, must be in matches
  - from: reference to Application, to send back the results once they are in
  - scores: the cache
  """
  defp handle_odds_for_match(match_id, from, matches, scores) do

    Logger.debug "the opponents for match #{match_id} are"
    get_opponents(matches, match_id)
    |> Enum.each(fn player ->
      Logger.debug (inspect player)

      case lookup(scores, player["id"]) do
	{:ok, cached_score} ->
	  Logger.debug "cached player #{player["id"]} score is #{cached_score}"
	  cached_player = Map.put(player, "score", cached_score)
	  send self(), {:reply, from, nil, cached_player}
	:error ->
	  pid = init_child()
	  Logger.debug "worker #{inspect pid} started"

	  GenServer.cast(pid, {:odds_for_match, from, self(), player})
      end
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
   Receives results from workers and compute the final result.
   Sends the final result to Application and cleans the state.

   If the partial results come from a worker, store it in cache and shutdown
   the worker.

   ## Parameters

    - {:reply, from, child_pid, player}: worker's message, where
       - from: reference to Application
       - child_pid: the worker, or nil if the message is send by self
       - player: the worker's result
    - state = %{odds, scores} : odds stores the partial results from workers,
    scores is the cache.
   """
  def handle_info({:reply, from, child_pid, player},
    state = %{odds: odds, scores: scores}) do
    Logger.debug "receive #{inspect player} from #{inspect child_pid}"

    new_odds = [player | odds]

    update_odds_in_state =
    if (length(new_odds) == 2) do
      result = normalise(new_odds)
      GenServer.reply(from, result)
      []
    else new_odds
    end

    if is_pid(child_pid) do
      insert(scores, {player["id"], player["score"]})
      Process.exit(child_pid, :shutdown)
      Logger.debug "worker #{inspect child_pid} shutdown"
    end

    {:noreply, %{state | odds: update_odds_in_state}}
  end

  def normalise(odds) do
    sum = Enum.reduce(odds, 0,
      fn player, acc -> player["score"] + acc
      end)

    Enum.reduce(odds, %{}, fn player, acc ->
      percentage = player["score"] / sum
      Map.put(acc, player["acronym"], percentage)
    end)
  end

  def get_opponents(matches, match_id) do
    matches
    |> Enum.find(fn match -> match["id"] == match_id end)
    |> Map.get("opponents")
    |> Enum.map(fn player ->
      Map.put(%{}, "acronym", player["opponent"]["acronym"])
      |> Map.put("id", player["opponent"]["id"])
    end)
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
