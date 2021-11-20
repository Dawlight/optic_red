defmodule OpticRed.Game.State.Rules.RoundEnd do
  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}

  use OpticRed.Game.State

  alias OpticRed.Game.ActionResult

  alias OpticRed.Game.Action.StartNewRound

  alias OpticRed.Game.Event.NewRoundStarted

  alias OpticRed.Game.State.Rules.Encipher

  def new(%Data{} = data) do
    %__MODULE__{data: data}
  end

  def handle_action(%__MODULE__{}, %StartNewRound{}) do
    ActionResult.new([NewRoundStarted.empty()])
  end

  def apply_event(%__MODULE__{data: data}, %NewRoundStarted{}) do
    Encipher.new(data)
  end
end
