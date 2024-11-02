defmodule InputProcess do
  @moduledoc false

  def start(interp_pid) do
    spawn(fn -> loop(interp_pid) end)
  end

  defp loop(interp_pid) do
    case IO.gets("") do
      :eof ->
        send(interp_pid, :eof)
        :ok

      {:error, reason} ->
        IO.puts("Ошибка чтения ввода: #{reason}")
        :ok

      line ->
        line = String.trim(line)
        case parse_line(line) do
          {:ok, {x, y}} ->
            send(interp_pid, {:new_point, x, y})
            loop(interp_pid)

          :error ->
            IO.puts("Некорректный ввод: #{line}")
            loop(interp_pid)
        end
    end
  end

  defp parse_line(line) do
    case String.split(line, ~r/[\s,;]+/) |> Enum.map(&parse_number/1) do
      [x, y] ->
        {:ok, {x, y}}

      _ ->
        :error
    end
  end

  defp parse_number(str) do
    case Integer.parse(str) do
      {int, ""} -> int * 1.0
      _ ->
        case Float.parse(str) do
          {float, ""} -> float
          _ -> raise ArgumentError, message: "not a valid number"
        end
    end
  end
end
