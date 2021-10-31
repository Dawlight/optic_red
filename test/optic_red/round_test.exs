defmodule OpticRed.GameSateTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.State.{
    Team,
    Round
  }

  test "Calculates positive and negative scores" do
    teams = [%Team{id: "red"}, %Team{id: "blue"}]

    %{"red" => 1, "blue" => -1} =
      %Round{
        code_by_team_id: %{"red" => [1, 2, 3], "blue" => [3, 2, 1]},
        attempts_by_team_id: %{
          "red" => %{"red" => [1, 2, 3], "blue" => [3, 2, 1]},
          "blue" => %{"red" => [3, 3, 3], "blue" => [3, 3, 3]}
        }
      }
      |> Round.get_score(teams)
  end

  test "Calculates no score" do
    teams = [%Team{id: "red"}, %Team{id: "blue"}]

    %{"red" => 0, "blue" => 0} =
      %Round{
        code_by_team_id: %{"red" => [1, 2, 3], "blue" => [3, 2, 1]},
        attempts_by_team_id: %{
          "red" => %{"red" => [1, 2, 3], "blue" => [3, 3, 3]},
          "blue" => %{"red" => [3, 3, 3], "blue" => [3, 2, 1]}
        }
      }
      |> Round.get_score(teams)
  end
end
