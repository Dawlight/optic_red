defmodule OpticRed.Game.State.Preparation do
  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}, ready_players: MapSet.new()

  use OpticRed.Game.State

  alias OpticRed.Game.Model.Round

  alias OpticRed.Game.ActionResult

  alias OpticRed.Game.Event.{
    PlayerReadied,
    WordsGenerated,
    NewRoundStarted
  }

  alias OpticRed.Game.Action.{
    GenerateWords,
    ReadyPlayer,
    StartNewRound
  }

  alias OpticRed.Game.State.Encipher

  @words ~w{cat tractor house tree love luck money table floor christmas orange}

  def new(data) do
    where(data: data, ready_players: MapSet.new())
  end

  #
  # Action Handlers
  #

  def handle_action(%__MODULE__{data: data}, %GenerateWords{team_id: team_id, words: words}) do
    case data |> Data.get_team_by_id(team_id) do
      nil ->
        ActionResult.empty()

      _ ->
        ActionResult.new([WordsGenerated.with(team_id: team_id, words: words)])
    end
  end

  def handle_action(%__MODULE__{} = state, %ReadyPlayer{player_id: player_id, ready?: ready?}) do
    %__MODULE__{data: data, ready_players: ready_players} = state

    case data |> Data.get_player_by_id(player_id) do
      nil ->
        ActionResult.empty()

      player ->
        player_ready? = ready_players |> MapSet.member?(player)

        case player_ready? != ready? do
          true ->
            ActionResult.new([PlayerReadied.with(player_id: player_id, ready?: ready?)])

          false ->
            ActionResult.empty()
        end
    end
  end

  def handle_action(%__MODULE__{} = state, %StartNewRound{}) do
    %__MODULE__{data: data, ready_players: ready_players} = state
    %Data{teams: teams} = data

    all_players = MapSet.new(data.players)

    all_teams_have_words? =
      !Enum.empty?(teams) and
        teams
        |> Enum.all?(fn team ->
          data.words_by_team_id[team.id] != nil
        end)

    case MapSet.equal?(all_players, ready_players) and all_teams_have_words? do
      true ->
        ActionResult.new([NewRoundStarted.empty()])

      false ->
        ActionResult.empty()
    end
  end

  #
  # Event Application
  #

  def apply_event(%__MODULE__{data: data} = state, %WordsGenerated{team_id: team_id, words: words}) do
    team = data |> Data.get_team_by_id(team_id)
    state |> where(data: data |> Data.set_team_words(team, words))
  end

  def apply_event(%__MODULE__{data: data} = state, %PlayerReadied{} = event) do
    %__MODULE__{ready_players: ready_players} = state
    %PlayerReadied{player_id: player_id, ready?: ready?} = event

    player = data |> Data.get_player_by_id(player_id)

    ready_players =
      case ready? do
        true ->
          [player | ready_players] |> Enum.uniq_by(& &1.id)

        false ->
          ready_players |> List.delete(player)
      end

    %__MODULE__{state | ready_players: ready_players}
  end

  def apply_event(%__MODULE__{data: data}, %NewRoundStarted{}) do
    %Data{teams: teams} = data

    {encipherer_by_team_id, data} =
      teams
      |> List.foldl({%{}, data}, fn team, {encipherer_by_team_id, data} ->
        {encipherer, data} = data |> Data.pop_random_encipherer(team)
        {encipherer_by_team_id |> Map.put(team.id, encipherer), data}
      end)

    code_by_team_id = for team <- teams, into: %{}, do: {team.id, get_random_code()}

    new_round =
      Round.empty()
      |> Round.with_default_attempts(teams)
      |> Round.with_default_clues(teams)
      |> Round.with_encipherers(encipherer_by_team_id)
      |> Round.with_codes(code_by_team_id)

    data = data |> Data.add_round(new_round)
    Encipher.where(data: data)
  end

  defp get_random_code(), do: Enum.take_random(1..4, 3)
end
