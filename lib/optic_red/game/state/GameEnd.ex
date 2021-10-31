defmodule OpticRed.Game.State.GameEnd do
  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}

  def new(%Data{} = data) do
    %__MODULE__{data: data}
  end

  def apply_event(%__MODULE__{} = state, _event) do
    state
  end
end
