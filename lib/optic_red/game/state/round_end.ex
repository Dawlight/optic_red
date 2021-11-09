defmodule OpticRed.Game.State.RoundEnd do
  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}

  alias OpticRed.Game.ActionResult

  alias OpticRed.Game.Action.StartNewRound

  alias OpticRed.Game.Event.NewRoundStarted

  alias OpticRed.Game.State.Encipher

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
