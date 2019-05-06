defmodule Panda.Rating do
  @moduledoc """
  Computes the odds for matches, based on previous results.
  """
  require Logger

  @doc """
  Computes odds by counting the number of matches won vs. the matches played.
  The odds are then normalised to sum to 1.
  """
  def normalise(players) do
    Enum.map(players, fn player ->
      {played, won} = statistics_player(player["matches"], player["id"])
      Logger.debug "team #{player["id"]} won #{won} matches out of #{played}"
      score = won/played
      Map.put(player, "score", score)
    end)
    |> normalise_odds
  end

  def normalise_odds(odds) do
    sum = Enum.reduce(odds, 0,
      fn player, acc -> player["score"] + acc
      end)

    Enum.reduce(odds, %{}, fn player, acc ->
      Map.put(acc, player["acronym"], player["score"] / sum)
    end)
  end

  def statistics_player(matches, team_id) do
    Enum.reduce(matches, {0,0},
      fn match, {played, won} ->
	winner_id = match["winner_id"]
	case winner_id do
	  nil -> {played, won}
	  ^team_id -> {played+1, won+1}
	  _winner_id -> {played+1, won}
	end
      end)
  end

  @initial_rating 1000
  @division_factor 400
  @k_value 16

  @doc """
  Computes odds using an elo rating system.
  The participants are every player playing at least once against either
  player1 or player2
  Stores participant id an rating in ets for fast access.
  A preprocessing is necessary to order matches in chronological order.
  Once ordered, each match updates the rating of its participants.
  Odds are returned for the two players based on current ratings.
  """
  def elo([player1, player2] = players) do
    ratings = :ets.new(:ratings, [:set, :protected])

    preprocess_for_elo(players)
    |> Enum.each(fn match ->
      update_ratings(match, ratings)
    end)

    odds = elo_odds(ratings, player1["id"], player2["id"])

    %{player1["acronym"] => elem(odds[1],1),
      player2["acronym"] => elem(odds[2],1)}
  end

  def elo(_args) do
    "elo rating system works for two players games"
  end

  defp preprocess_for_elo(players) do

    Enum.reduce(players, [], fn player, acc ->
      Enum.concat(acc, player["matches"])
    end)

    |> Enum.filter(fn match ->
      (match["winner_id"] != nil) and (match["opponent_id"] != nil)
    end)

    |> Enum.map(&update_time(&1))

    |> Enum.sort(fn a,b ->
      :gt != NaiveDateTime.compare(a["begin_at"], b["begin_at"])
    end)
  end

  @doc """
  Computes odds using the ratings stored in table.
  """
  def elo_odds(table, player1, player2) do
    rating1 = get_rating(table, player1)
    rating2 = get_rating(table, player2)

    proba1 = probability(rating1, rating2)
    proba2 = probability(rating2, rating1)

    Logger.debug "player #{player1} rating = #{rating1} and proba = #{proba1}"
    Logger.debug "player #{player2} rating = #{rating2} and proba = #{proba2}"

    %{1 => {rating1, proba1}, 2 => {rating2, proba2}}
  end

  @doc """
  Updates ratings in table using the result of the match.
  """
  def update_ratings(match, table) do
    odds = elo_odds(table, match["opponent_id"], match["winner_id"])

    {opponent_rating, opponent_proba} = odds[1]
    {winner_rating, winner_proba} = odds[2]

    opponent_rating = update_rating(opponent_rating, 0, opponent_proba)
    winner_rating = update_rating(winner_rating, 1, winner_proba)

    Logger.debug "opponent rating after match #{opponent_rating}"
    Logger.debug "winner rating after match #{winner_rating}"

    :ets.insert(table, {match["opponent_id"], opponent_rating})
    :ets.insert(table, {match["winner_id"], winner_rating})
  end

  defp update_rating(rating, actual, expected) do
    Float.floor(rating + @k_value * (actual - expected), 2)
  end

  defp probability(rating1, rating2) do
    n = (rating1 - rating2) / @division_factor
    1/ (1 + :math.pow(10, n))
  end

  defp get_rating(table,key) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> value
      [] ->
	:ets.insert(table, {key, @initial_rating})
	@initial_rating
    end
  end

  defp update_time(match) do
    [date, time] = String.split(match["begin_at"], "T")
    [year, month, day] =
      String.split(date, "-")
      |> Enum.map(&String.to_integer(&1))
    time = String.trim(time, "Z")

    [hour, minute, second] =
      String.split(time, ":")
      |> Enum.map(&String.to_integer(&1))

    {:ok, update} = NaiveDateTime.new(year, month, day, hour, minute, second)
    Map.put(match, "begin_at", update)
  end
end
