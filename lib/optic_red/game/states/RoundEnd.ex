defmodule OpticRed.Game.State.RoundEnd do
  alias OpticRed.Game.State.Data
  defstruct data: %Data{}

  alias OpticRed.Game.Event.NewRoundStarted

  def new(%Data{} = data) do
    %__MODULE__{data: data}
  end

  def apply_event(%__MODULE__{data: data}, %NewRoundStarted{}) do
    Encipher.new(data)
  end
end
