# Лабораторная работа №3

* Студент: `Билобрам Денис Андреевич`
* Группа: `P3319`
* ИСУ: `367893`

## Описание работы

Цель: получить навыки работы с вводом/выводом, потоковой обработкой данных, командной строкой.
В рамках лабораторной работы вам предлагается повторно реализовать лабораторную работу по предмету "Вычислительная математика" посвящённую интерполяции (в разные годы это лабораторная работа 3 или 4) со следующими дополнениями:

* обязательно должна быть реализована линейная интерполяция (отрезками, link);
* настройки алгоритма интерполяции и выводимых данных должны задаваться через аргументы командной строки:

  * какие алгоритмы использовать (в том числе два сразу);
  * частота дискретизации результирующих данных;
  * и т.п.;

* входные данные должны задаваться в текстовом формате на подобии ".csv" (к примеру x;y\n или x\ty\n) и подаваться на стандартный ввод, входные данные должны быть отсортированы по возрастанию x;
* выходные данные должны подаваться на стандартный вывод;
* программа должна работать в потоковом режиме (пример -- cat | grep 11), это значит, что при запуске программы она должна ожидать получения данных на стандартный ввод, и, по мере получения достаточного количества данных, должна выводить рассчитанные точки в стандартный вывод;

## Архитектура приложения

```
+---------------------------+
|     Обработка входного     |
|          потока           |
|       (InputProcess)      |
+---------------------------+
             |
             | Новая точка
             v
+---------------------------+
|   Алгоритм интерполяции   |
|        и генерация        |
|     точек (Interpolation  |
|       Process/GenServer)  |
+---------------------------+
             |
             | Результаты вычислений
             v
+---------------------------+
|      Печать значений      |
|      (OutputProcess)      |
+---------------------------+
```

## Описание модулей

### CLI

Модуль CLI обрабатывает аргументы командной строки и запускает процессы. Здесь выполняется парсинг аргументов, включая алгоритмы интерполяции (--algorithms) и шаг дискретизации (--step). После этого CLI инициализирует процессы ввода, интерполяции и вывода.

``` elixir
def main(args) do

  {opts, _, _} = OptionParser.parse(args, switches: [algorithms: :string, step: :float])

  algorithms = opts[:algorithms] || "linear"
  step = opts[:step] || 1.0
  algorithms = String.split(algorithms, ",") |> Enum.map(&String.to_atom/1)

  OutputProcess.start()

  {:ok, interp_pid} = InterpolationProcess.start(algorithms: algorithms, step: step)

  InputProcess.start(interp_pid)

  Process.sleep(:infinity)

end
```

### InputProcess

InputProcess — это процесс, который считывает данные из стандартного ввода (stdin) и передает их в процесс интерполяции в виде сообщений. Основные функции:

- Считывание строк из stdin.
- Парсинг строк для преобразования их в точки данных.
- Отправка сообщений с новыми точками в InterpolationProcess.

``` elixir
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
```

### InterpolationProcess
InterpolationProcess реализован как GenServer.

Основные функции:
- Получение точек данных и накопление их в буфере.
- Генерация промежуточных значений для интерполяции.
- Выполнение интерполяции в зависимости от накопленных точек и переданных аргументов.
- Отправка результатов интерполяции в OutputProcess для вывода.

``` elixir
defmodule InterpolationProcess do
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
```

### OutputProcess
OutputProcess — это процесс, который получает результаты интерполяции от InterpolationProcess, форматирует их и выводит в стандартный вывод. Форматирование включает вывод точек x и интерполированных значений y в удобном табличном виде.
``` elixir
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
```
---

Программа поддерживает потоковый режим, то есть продолжает обрабатывать и интерполировать данные по мере их поступления, пока не достигнет конца ввода.

## Пример работы
`echo -e "0 0.00\n1.571 1\n3.142 0\n4.712 -1\n12.568 0" | ./interpolation --algorithms linear,lagrange --step 1.0`
```
Linear интерполяция:
0.0     1.0     2.0
0.0     0.64    1.27

Linear интерполяция:
1.57    2.57    3.57
1.0     0.36    -0.27

Linear интерполяция:
3.14    4.14    5.14
0.0     -0.64   -1.27

Lagrange интерполяция:
0.0     1.0     2.0     3.0     4.0     5.0
0.0     0.97    0.84    0.12    -0.67   -1.03

Linear интерполяция:
4.71    5.71    6.71    7.71    8.71    9.71    10.71   11.71   12.71
-1.0    -0.87   -0.75   -0.62   -0.49   -0.36   -0.24   -0.11   0.02

Lagrange интерполяция:
1.57    2.57    3.57    4.57    5.57    6.57    7.57    8.57    9.57    10.57   11.57   12.57
1.0     0.37    -0.28   -0.91   -1.49   -1.95   -2.26   -2.38   -2.25   -1.84   -1.11   0.0
```