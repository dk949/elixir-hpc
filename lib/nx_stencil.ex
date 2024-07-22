defmodule NxStencil do
  defmodule StencilData do
    @enforce_keys [
      :up_rank,
      :self_rank,
      :down_rank,
      :top_halo,
      :self_data,
      :bottom_halo
    ]

    defstruct @enforce_keys
  end

  defmodule InitData do
    @enforce_keys [:parent, :data, :iters]

    defstruct @enforce_keys
  end

  defp access(nil, _, _), do: 0.0
  defp access(_, x, size) when x < 0 or x > size - 1, do: 0.0
  defp access(arr, x, _), do: Enum.at(arr, x)

  defp compute(top_halo, data, bottom_halo) do
    data_length = length(data)

    for i <- 0..(data_length - 1) do
      (access(top_halo, i - 1, data_length) +
         access(top_halo, i, data_length) +
         access(top_halo, i + 1, data_length) +
         access(data, i - 1, data_length) +
         access(data, i, data_length) +
         access(data, i + 1, data_length) +
         access(bottom_halo, i - 1, data_length) +
         access(bottom_halo, i, data_length) +
         access(bottom_halo, i + 1, data_length)) / 9
    end
  end

  defp receive_from_top() do
    receive do
      {:halo_from_top, value} -> value
    after
      2000 -> throw("Could not receive from top")
    end
  end

  defp receive_from_bottom() do
    receive do
      {:halo_from_bottom, value} -> value
    after
      2000 -> throw("Could not receive from bottom")
    end
  end

  defp worker(parent, rank, _, _, _, data, _, 0) do
    IO.puts("#{rank}: finished")
    send(parent, {:end_data, rank, data})
  end

  defp worker(parent, rank, up, down, top_halo, data, bottom_halo, iters) do
    data = compute(top_halo, data, bottom_halo)

    {top_halo, bottom_halo} =
      case {up, down} do
        # Top row, only down exists
        {nil, down} ->
          send(down, {:halo_from_top, data})
          {nil, receive_from_bottom()}

        # Bottom row, only up exists
        {up, nil} ->
          send(up, {:halo_from_bottom, data})
          {receive_from_top(), nil}

        # Middle rows
        {up, down} ->
          send(up, {:halo_from_bottom, data})
          send(down, {:halo_from_top, data})
          {receive_from_top(), receive_from_bottom()}
      end

    worker(parent, rank, up, down, top_halo, data, bottom_halo, iters - 1)
  end

  defp process_start do
    receive do
      %InitData{
        parent: parent,
        data: %StencilData{
          up_rank: up,
          self_rank: rank,
          down_rank: down,
          top_halo: top_halo,
          self_data: init_data,
          bottom_halo: bottom_halo
        },
        iters: iters
      } ->
        worker(parent, rank, up, down, top_halo, init_data, bottom_halo, iters)
    end
  end

  defp all_not_nil(lst) do
    lst
    |> Stream.map(fn x -> x != nil end)
    |> Enum.reduce(true, fn x, acc -> x and acc end)
  end

  defp collect_impl(list) do
    # Can't call function in guard?
    if all_not_nil(list) do
      list
    else
      receive do
        {:end_data, rank, data} -> collect_impl(list |> List.replace_at(rank, data))
      end
    end
  end

  defp collect(count) do
    collect_impl(List.duplicate(nil, count))
  end

  defp get_data(x_dim, y_dim) do
    # 2d array of incrementing numbers from 0 to x*y
    # Nx.tensor(Enum.chunk_every(0..(x_dim * y_dim - 1), y_dim), type: :f64)
    Enum.chunk_every(0..(x_dim * y_dim - 1), y_dim)
  end

  defp run_impl() do
    # For now, process count == row count
    proc_count = 64
    iters = 100
    x_dim = proc_count
    y_dim = 1000
    IO.puts("start")
    data = get_data(x_dim, y_dim)

    procs =
      for rank <- 0..(proc_count - 1) do
        {
          rank,
          spawn(&process_start/0)
        }
      end

    IO.puts("spawned")

    inner_pids =
      procs
      |> Enum.map(fn {rank, proc} -> {rank, proc, Enum.at(data, rank)} end)
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.map(fn [
                       {_, up, top_halo},
                       {this_rank, this, init_data},
                       {_, down, bottom_halo}
                     ] ->
        send(
          this,
          %InitData{
            parent: self(),
            data: %StencilData{
              up_rank: up,
              self_rank: this_rank,
              down_rank: down,
              top_halo: top_halo,
              self_data: init_data,
              bottom_halo: bottom_halo
            },
            iters: iters
          }
        )

        this
      end)

    IO.puts("sent inner")

    {fst_rank, fst} = List.first(procs)
    {lst_rank, lst} = List.last(procs)

    send(
      fst,
      %InitData{
        parent: self(),
        data: %StencilData{
          up_rank: nil,
          self_rank: fst_rank,
          down_rank: List.first(inner_pids),
          top_halo: nil,
          self_data: Enum.at(data, 0),
          bottom_halo: Enum.at(data, 1)
        },
        iters: iters
      }
    )

    send(
      lst,
      %InitData{
        parent: self(),
        data: %StencilData{
          up_rank: List.last(inner_pids),
          self_rank: lst_rank,
          down_rank: nil,
          top_halo: Enum.at(data, length(data) - 2),
          self_data: Enum.at(data, length(data) - 1),
          bottom_halo: nil
        },
        iters: iters
      }
    )

    IO.puts("sent fst, lst")

    IO.puts("Waiting for result")

    collect(proc_count)
  end

  def run(out \\ "data_out.json") do
    {time, data} = :timer.tc(&run_impl/0)
    IO.puts("Took #{time / 1000_000}s")

    File.write(out, data |> inspect(limit: :infinity))
  end
end
