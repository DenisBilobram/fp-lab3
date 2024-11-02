defmodule InterpolationProcess do
  @moduledoc false

  use GenServer

  def start(opts) do
    GenServer.start(__MODULE__, opts, name: __MODULE__)
  end

  def init(state) do
    algorithms = state[:algorithms]
    step = state[:step]
    {:ok, %{points: [], algorithms: algorithms, step: step}}
  end

  def handle_info({:new_point, x, y}, state) do
    points = state.points ++ [{x, y}]
    state = %{state | points: points}

    Enum.each(state.algorithms, fn algorithm ->
      case can_interpolate?(algorithm, points) do
        true ->
          perform_interpolation(algorithm, points, state.step)

        false ->
          :ok
      end
    end)

    {:noreply, state}
  end

  def handle_info(:eof, state) do
    {:noreply, state}
  end

  defp can_interpolate?(:linear, points) do
    length(points) >= 2
  end

  defp can_interpolate?(:lagrange, points) do
    length(points) >= 4
  end

  defp perform_interpolation(:linear, points, step) do
    [p1, p2 | _] = Enum.take(points, -2)
    {x1, y1} = p1
    {x2, y2} = p2

    x_start = x1
    x_end = x2 + step
    x_values = generate_x_values(x_start, x_end, step)

    y_values = Enum.map(x_values, fn x ->
      linear_interpolation({x1, y1}, {x2, y2}, x)
    end)

    send_output(:linear, x_values, y_values)
  end

  defp perform_interpolation(:lagrange, points, step) do
    lagrange_points = get_lagrange_points(points)
    x_start = List.first(lagrange_points) |> elem(0)
    x_end = elem(List.last(lagrange_points), 0) + step
    x_values = generate_x_values(x_start, x_end, step)

    y_values = Enum.map(x_values, fn x ->
      lagrange_interpolation(lagrange_points, x)
    end)

    send_output(:lagrange, x_values, y_values)
  end

  defp get_lagrange_points(points) do
    window_size = 4
    if length(points) >= window_size do
      Enum.slice(points, -window_size, window_size)
    else
      points
    end
  end

  defp generate_x_values(x_start, x_end, step) do
    Stream.iterate(x_start, &(&1 + step))
    |> Stream.take_while(&(&1 <= x_end))
    |> Enum.to_list()
  end

  defp linear_interpolation({x1, y1}, {x2, y2}, x) do
    y1 + ((x - x1) * (y2 - y1)) / (x2 - x1)
  end

  defp lagrange_interpolation(points, x) do
    Enum.reduce(points, 0.0, fn {xi, yi}, acc ->
      li = calculate_lagrange_multiplier(points, x, xi)
      acc + yi * li
    end)
  end

  defp calculate_lagrange_multiplier(points, x, xi) do
    Enum.reduce(points, 1.0, fn {xj, _}, acc_li ->
      if xi != xj do
        acc_li * (x - xj) / (xi - xj)
      else
        acc_li
      end
    end)
  end

  defp send_output(algorithm, x_values, y_values) do
    output_pid = Process.whereis(OutputProcess)
    send(output_pid, {:interpolation_result, algorithm, x_values, y_values})
  end
end
