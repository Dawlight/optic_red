defmodule OpticRed.Game.Event.LeadTeamPassed do
  defstruct [:lead_team, :remaining_lead_teams]
  use OpticRed.Game.Event
end
