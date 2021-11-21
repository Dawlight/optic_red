defmodule OpticRed.Game.State.Rules.Preparation do
  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}, ready_players: MapSet.new()

  use OpticRed.Game.State

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

  alias OpticRed.Game.State.Rules.Encipher

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
          ready_players |> MapSet.put(player)

        false ->
          ready_players |> MapSet.delete(player)
      end

    state |> where(ready_players: ready_players)
  end

  def apply_event(%__MODULE__{data: data}, %NewRoundStarted{}) do
    Encipher.new(data)
  end
end