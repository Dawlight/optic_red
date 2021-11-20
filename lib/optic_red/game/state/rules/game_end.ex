defmodule OpticRed.Game.State.Rules.GameEnd do
  @moduledoc false

  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}, winning_teams: [], losing_teams: []

  use OpticRed.Game.State

  def apply_event(%__MODULE__{} = state, _event) do
    state
  end
end
