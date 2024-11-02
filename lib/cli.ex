defmodule CLI do
  @moduledoc false

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
end
