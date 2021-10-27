defmodule OpticRed.Game.State.Encipher do
  alias OpticRed.Game.State.Data
  defstruct data: %Data{}

  alias OpticRed.Game.Event.CluesSubmitted

  def new(%Data{} = data) do
    %__MODULE__{data: data}
  end

  def apply_event(%__MODULE__{} = state, %CluesSubmitted{team_id: team_id, clues: clues}) do
    %__MODULE__{data: data} = state
    # data = data |> Data.update_round(0, &Round.)
  end
end
