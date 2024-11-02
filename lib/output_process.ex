defmodule OutputProcess do
  @moduledoc false

  def start do
    spawn(fn ->
      Process.register(self(), __MODULE__)
      loop()
    end)
  end

  defp loop do
    receive do
      {:interpolation_result, algorithm, x_values, y_values} ->
        IO.puts("\n#{String.capitalize(to_string(algorithm))} интерполяция:")

        x_line = Enum.map_join(x_values, "\t", &Float.round(&1, 2))
        y_line = Enum.map_join(y_values, "\t", &Float.round(&1, 2))

        IO.puts(x_line)
        IO.puts(y_line)
        loop()

      _other ->
        loop()
    end
  end
end
