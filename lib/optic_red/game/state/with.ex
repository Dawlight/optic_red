defmodule OpticRed.Game.State.With do
  defmacro __using__(_opts) do
    quote do
      alias __MODULE__

      def with(%__MODULE__{} = data, new_data) when is_list(new_data) do
        new_data = new_data |> Enum.into(%{})

        __MODULE__.with(data, new_data)
      end

      def with(%__MODULE__{} = data, new_data) when is_map(new_data) do
        struct(__MODULE__, Map.merge(Map.from_struct(data), new_data))
      end

      def empty() do
        %__MODULE__{}
      end
    end
  end
end