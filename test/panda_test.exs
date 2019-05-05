defmodule PandaTest do
  use ExUnit.Case, async: false
  doctest Panda

  test "greets the world" do
    assert Panda.hello() == :world
  end

  test "odds_for_match check arguments" do
    IO.inspect "this test first"
    assert (Panda.odds_for_match(1) ==
      "please call Panda.upcoming_matches first")
  end

  test "odds_for_match check arguments 2" do
    IO.inspect "that test second"
    Panda.upcoming_matches

    assert (Panda.odds_for_match(1) ==
      "please provide a match id from the upcoming matches")
  end

  test "5 upcoming matches" do
    assert (Enum.count Panda.upcoming_matches) == 5
  end

  test "get opponents for a match" do
    matches = test_matches()
    assert (Panda.Server.get_opponents(matches, 544235) ==
      [%{"acronym" => "iG.V", "id" => 1650},
       %{"acronym" => "Aster.A", "id" => 126000}])
  end

  test "normalise scores" do
    odds = [ %{"acronym" => "iG.V", "id" => 1650, "score" => 1.2},
  	     %{"acronym" => "Aster.A", "id" => 126000, "score" => 1.7}]
    assert (Panda.Server.normalise(odds) == %{"Aster.A" => 0.5862068965517241,
  					      "iG.V" => 0.41379310344827586})
  end

  test "statistics for a team" do
    opponents_id = matches_opponent_winner()
    assert (Panda.Worker.statistics_player(opponents_id, 1664) == {44,30})
  end

  def test_matches do
    [
      %{
	"begin_at" => "2019-05-05T08:00:00Z",
	"id" => 544235,
	"name" => "iG.V vs Aster.A",
	"opponents" => [
	  %{
            "opponent" => %{
          "acronym" => "iG.V",
          "id" => 1650,
          "image_url" => "https://cdn.pandascore.co/images/team/image/1650/iG_Vitality.png",
          "name" => "iG.Vitality",
          "slug" => "ig-vitality"
        },
            "type" => "Team"
	  },
	  %{
            "opponent" => %{
          "acronym" => "Aster.A",
          "id" => 126000,
          "image_url" => "https://cdn.pandascore.co/images/team/image/126000/Aster.Aquarius_logo.png",
          "name" => "Aster.Aquarius",
          "slug" => "aster-aquarius"
        },
            "type" => "Team"
	  }
	]
      },
      %{
	"begin_at" => "2019-05-05T08:00:00Z",
	"id" => 544138,
	"name" => "Elimination Match",
	"opponents" => [
	  %{
            "opponent" => %{
          "acronym" => "Empire",
          "id" => 1649,
          "image_url" => "https://cdn.pandascore.co/images/team/image/1649/Team_Empire.png",
          "name" => "Team Empire",
          "slug" => "team-empire"
        },
            "type" => "Team"
	  },
	  %{
            "opponent" => %{
          "acronym" => "NiP",
          "id" => 3356,
          "image_url" => "https://cdn.pandascore.co/images/team/image/3356/600px-Ninjas_in_Pyjamas_2017.png",
          "name" => "Ninjas in Pyjamas",
          "slug" => "ninjas-in-pyjamas-35f2e134-7b7c-4353-a591-effcdd5a8595"
        },
            "type" => "Team"
	  }
	]
      },
      %{
	"begin_at" => "2019-05-05T08:00:00Z",
	"id" => 544133,
	"name" => "Elimination Match",
	"opponents" => [
	  %{
            "opponent" => %{
          "acronym" => "KG",
          "id" => 1673,
          "image_url" => "https://cdn.pandascore.co/images/team/image/1673/Keen_Gaming.png",
          "name" => "KEEN GAMING",
          "slug" => "keen-gaming"
        },
            "type" => "Team"
	  },
	  %{
            "opponent" => %{
          "acronym" => "BC",
          "id" => 126002,
          "image_url" => "https://cdn.pandascore.co/images/team/image/126002/147px-Beastcoast_no_text.png",
          "name" => "beastcoast",
          "slug" => "beastcoast"
        },
            "type" => "Team"
	  }
	]
      },
      %{
	"begin_at" => "2019-05-05T08:00:00Z",
	"id" => 544001,
	"name" => "INTZ vs VEG",
	"opponents" => [
	  %{
            "opponent" => %{
          "acronym" => "INTZ",
          "id" => 158,
          "image_url" => "https://cdn.pandascore.co/images/team/image/158/intz-ijdoekud.png",
          "name" => "INTZ e-Sports Club",
          "slug" => "intz"
        },
            "type" => "Team"
	  },
	  %{
            "opponent" => %{
          "acronym" => "VEG",
          "id" => 664,
          "image_url" => "https://cdn.pandascore.co/images/team/image/664/vega-squadron-giuegvf3.png",
          "name" => "Vega Squadron",
          "slug" => "vega-squadron"
        },
            "type" => "Team"
	  }
	]
      },
      %{
	"begin_at" => "2019-05-05T09:00:00Z",
	"id" => 544113,
	"name" => "TSG vs WEA",
	"opponents" => [
	  %{
            "opponent" => %{
          "acronym" => "TSG",
          "id" => 125993,
          "image_url" => "https://cdn.pandascore.co/images/team/image/125993/Triumphant_Song_Gaminglogo_square.png",
          "name" => "Triumphant Song Gaming",
          "slug" => "triumphant-song-gaming"
        },
            "type" => "Team"
	  },
	  %{
            "opponent" => %{
          "acronym" => "WEA",
          "id" => 125992,
          "image_url" => "https://cdn.pandascore.co/images/team/image/125992/Team_WE_Academylogo_square.png",
          "name" => "Team WE Academy",
          "slug" => "team-we-academy"
        },
            "type" => "Team"
	  }
	]
      }
    ]
  end


  def matches_opponent_winner do
    [
      %{"opponent_id" => 1664, "winner_id" => nil},
      %{"opponent_id" => 1655, "winner_id" => 1664},
      %{"opponent_id" => 1677, "winner_id" => 1664},
      %{"opponent_id" => 2061, "winner_id" => 1664},
      %{"opponent_id" => 2059, "winner_id" => 1664},
      %{"opponent_id" => 1664, "winner_id" => 1651},
      %{"opponent_id" => 1664, "winner_id" => 1676},
      %{"opponent_id" => 1673, "winner_id" => 1664},
      %{"opponent_id" => 1651, "winner_id" => 1664},
      %{"opponent_id" => 3356, "winner_id" => 1664},
      %{"opponent_id" => 1659, "winner_id" => 1664},
      %{"opponent_id" => 1664, "winner_id" => 3356},
      %{"opponent_id" => 1664, "winner_id" => 1654},
      %{"opponent_id" => 1677, "winner_id" => 1664},
      %{"opponent_id" => 1664, "winner_id" => 3359},
      %{"opponent_id" => 1664, "winner_id" => nil},
      %{"opponent_id" => 1664, "winner_id" => nil},
      %{"opponent_id" => 125180, "winner_id" => 1664},
      %{"opponent_id" => 1706, "winner_id" => 1664},
      %{"opponent_id" => 3360, "winner_id" => 1664},
      %{"opponent_id" => 1677, "winner_id" => 1664},
      %{"opponent_id" => 3352, "winner_id" => 1664},
      %{"opponent_id" => 2229, "winner_id" => 1664},
      %{"opponent_id" => 2059, "winner_id" => 1664},
      %{"opponent_id" => 1664, "winner_id" => 1657},
      %{"opponent_id" => 1647, "winner_id" => 1664},
      %{"opponent_id" => 3385, "winner_id" => 1664},
      %{"opponent_id" => 1664, "winner_id" => 1687},
      %{"opponent_id" => 1653, "winner_id" => 1664},
      %{"opponent_id" => 1706, "winner_id" => 1664},
      %{"opponent_id" => 1655, "winner_id" => 1664},
      %{"opponent_id" => 1677, "winner_id" => 1664},
      %{"opponent_id" => 3353, "winner_id" => 1664},
      %{"opponent_id" => 1825, "winner_id" => 1664},
      %{"opponent_id" => 1664, "winner_id" => 1653},
      %{"opponent_id" => 3385, "winner_id" => 1664},
      %{"opponent_id" => 1664, "winner_id" => 1651},
      %{"opponent_id" => 3353, "winner_id" => 1664},
      %{"opponent_id" => 1664, "winner_id" => 1657},
      %{"opponent_id" => 3359, "winner_id" => 1664},
      %{"opponent_id" => 1656, "winner_id" => 1664},
      %{"opponent_id" => 3397, "winner_id" => 1664},
      %{"opponent_id" => 2640, "winner_id" => 1664},
      %{"opponent_id" => 1664, "winner_id" => 1656},
      %{"opponent_id" => 1664, "winner_id" => 2594},
      %{"opponent_id" => 1664, "winner_id" => 1653},
      %{"opponent_id" => 2576, "winner_id" => nil},
      %{"opponent_id" => 1664, "winner_id" => 1657}]
  end




end
