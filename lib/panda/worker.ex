defmodule Panda.Worker do
  @moduledoc """
  Calls the panda api.
  Preprocess results before sending them to the Server.
  """

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
    matches =
      get(:upcoming_matches)
      |> preprocess_upcoming_matches

    {:reply, matches, state}
  end

  def handle_cast({:odds_for_match, pid, player, match_id}, state) do
    player =
      get(:score, player["id"])
      |> preprocess_odds_for_match(player)

    send pid, {:reply, self(), player, match_id}
    {:noreply, state}
  end

  defp preprocess_upcoming_matches(json) do
    Enum.map(json,
      fn match ->
	Map.put(%{}, "begin_at", match["begin_at"])
	|> Map.put("id", match["id"])
	|> Map.put("name", match["name"])
	|> Map.put("opponents", match["opponents"])
      end)
  end

  defp preprocess_odds_for_match(json, player) do
    Logger.info "working ..."

    matches =
      Enum.map(json,
	fn match ->
	  opponent_id = get_opponent_id(match)
	  Map.put(%{}, "begin_at", match["begin_at"])
	  |> Map.put("winner_id", match["winner_id"])
	  |> Map.put("opponent_id", opponent_id)
	end)
    Logger.debug "matches for #{player["id"]} are #{inspect matches}"

    Map.put(player, "matches", matches)
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
