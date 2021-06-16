defmodule OpticRed do
  @moduledoc """
  OpticRed keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def start_new_game() do
    OpticRed.Game.start_new()
  end
end
