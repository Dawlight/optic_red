defmodule OpticRed.Game.State.GameEnd do
  alias OpticRed.Game.State.Data
  defstruct data: %Data{}

  def new(%Data{} = data) do
    %__MODULE__{data: data}
  end
end
