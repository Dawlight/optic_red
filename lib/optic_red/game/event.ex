defmodule OpticRed.Game.Event do
  defmacro __using__(_opts) do
    quote do
      alias __MODULE__

      def with(data) when is_list(data) do
        data = data |> Enum.into(%{})

        __MODULE__.with(data)
      end

      def with(data) when is_map(data) do
        struct(__MODULE__, data)
      end

      def empty() do
        %__MODULE__{}
      end
    end
  end
end
