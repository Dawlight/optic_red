defmodule OpticRed.Game.ActionResult do
  defstruct events: []

  def empty() do
    %__MODULE__{}
  end

  def new(events) do
    %__MODULE__{events: events}
  end

  def add(%__MODULE__{events: events}, %__MODULE__{events: new_events}) do
    new(events ++ new_events)
  end
end
