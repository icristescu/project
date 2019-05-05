defmodule Panda do
  @moduledoc """
  Documentation for Panda.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Panda.hello()
      :world

  """
  def hello do
    :world
  end

  def upcoming_matches do
    Panda.Application.upcoming_matches()
  end

  def odds_for_match(match_id) do
    Panda.Application.odds_for_match(match_id)
  end
end
