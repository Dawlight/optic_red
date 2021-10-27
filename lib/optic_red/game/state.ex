defmodule OpticRed.Game.State do
  alias OpticRed.Game.State.Setup
  alias OpticRed.Game.State.Data

  defmacro __using__(_opt) do
    quote do
      alias __MODULE__

      def with(%__MODULE__{} = data, new_data) when is_list(new_data) do
        new_data = new_data |> Enum.into(%{})

        __MODULE__.with(data, new_data)
      end

      def with(%__MODULE__{} = data, new_data) when is_map(new_data) do
        struct(__MODULE__, Map.merge(Map.from_struct(data), new_data))
      end

      def with(new_data) when is_list(new_data) do
        new_data = new_data |> Enum.into(%{})

        __MODULE__.with(new_data)
      end

      def with(new_data) when is_map(new_data) do
        struct(__MODULE__, new_data)
      end

      def empty() do
        %__MODULE__{}
      end
    end
  end

  ###
  ### Public
  ###

  def build_state(history, initial_state) do
    history
    |> List.foldl(initial_state, fn event, state ->
      apply_event(state, event)
    end)
  end

  def apply_event(state, event) do
    state
    |> module()
    |> apply(:apply_event, [state, event])
  end

  defp module(state), do: state.__struct__

  def get_game_id_name(game_id), do: {:n, :l, {:game_state, game_id}}
end
