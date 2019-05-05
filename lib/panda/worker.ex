defmodule Panda.Worker do

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    Logger.info "new worker started..."
    {:ok, %{}}
  end

  def handle_call(:upcoming_matches, _from, state) do
    json = get(:upcoming_matches)

    matches = Enum.map(json,
      fn match ->
	Map.put(%{}, "begin_at", match["begin_at"])
	|> Map.put("id", match["id"])
	|> Map.put("name", match["name"])
	|> Map.put("opponents", match["opponents"])
      end)

    {:reply, matches, state}
  end

  def handle_cast({:odds_for_match, from, pid, player}, state) do
    json = get(:score, player["id"])

    score = score(json, player["id"])
    player = Map.put(player, "score", score)
    send pid, {:reply, from, self(), player}
    {:noreply, state}
  end

  defp score(matches, team_id) do
    Logger.info "working ..."

    opponents_id =
      Enum.map(matches,
	fn match ->
	  opponent_id = get_opponent_id(match)
	  Map.put(%{}, "winner_id", match["winner_id"])
	  |> Map.put("opponent_id", opponent_id)
	end)
    Logger.debug "opponents_id for #{team_id} are #{inspect opponents_id}"

    {played, won} = statistics_player(opponents_id, team_id)
    Logger.debug "team #{team_id} won #{won} matches out of #{played}"

    won/played
  end

  def statistics_player(opponents_id, team_id) do
    Enum.reduce(opponents_id, {0,0},
      fn match, {played, won} ->
	winner_id = match["winner_id"]
	case winner_id do
	  nil -> {played, won}
	  ^team_id -> {played+1, won+1}
	  _winner_id -> {played+1, won}
	end
      end)
  end

  defp get_opponent_id(match) do
    winner_id = match["winner_id"]
    opponent =
      Enum.find(match["opponents"],
	fn player -> player["opponent"]["id"] != winner_id
	end)
    opponent["opponent"]["id"]
  end

  defp get(:upcoming_matches) do
    HTTPoison.start

    "matches/upcoming?page[size]=5&"
    |> url
    |> HTTPoison.get
    |> http_response
  end

  defp get(:score, team_id) do

    response =
    ("teams/#{team_id}/matches?page[size]=50&")
    |> url
    |> HTTPoison.get
    |> http_response

    if response == :timeout do get(:score, team_id)
    else response
    end

  end


  defp http_response(
    {:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    {:ok, json} = JSON.decode(body)
    json
  end
  defp http_response({:ok, %HTTPoison.Response{status_code: status}}) do
    Logger.warn "http response unexpected status code #{inspect status}"
  end
  defp http_response({:error, %HTTPoison.Error{reason: reason}}) do
    Logger.warn "http error #{reason}"
    reason
  end

  defp token do
    "llIO0ZZH2W1P1Q4M4LEApVG9Nh5RNqHjroMCXRXOqAdeoL-MRiM"
  end

  defp url(msg) do
    "https://api.pandascore.co/"<> msg <>"token=#{token()}"
  end
end
