defmodule OpticRed.Game.Event.CluesSubmitted do
  defstruct [:team_id, clues: nil]
  use OpticRed.Game.Event
end
