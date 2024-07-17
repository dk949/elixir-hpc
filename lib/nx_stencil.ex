defmodule NxStencil do
  def enumerate(lst) do
    Enum.zip(lst, Stream.iterate(0, &(&1 + 1)))
  end

  def access(nil, _, _), do: 0.0
  def access(_, x, size) when x < 0 or x > size - 1, do: 0.0
  def access(arr, x, _), do: Enum.at(arr, x)

  def len_or_nil(nil), do: "nil"
  def len_or_nil(v), do: inspect(length(v))

  def compute(top_halo, data, bottom_halo) do
    data_length = length(data)

    for i <- 0..(data_length - 1) do
      (NxStencil.access(top_halo, i - 1, data_length) + NxStencil.access(top_halo, i, data_length) + NxStencil.access(top_halo, i + 1, data_length) +
         NxStencil.access(data, i - 1, data_length) +
         NxStencil.access(data, i, data_length) +
         NxStencil.access(data, i + 1, data_length) +
         NxStencil.access(bottom_halo, i - 1, data_length) +
         NxStencil.access(bottom_halo, i, data_length) +
         NxStencil.access(bottom_halo, i + 1, data_length)) / 9
    end
  end

  def receive_from_top() do
    receive do
      {:halo_from_top, value} -> value
    after
      2000 -> throw("Could not receive from top")
    end
  end

  def receive_from_bottom() do
    receive do
      {:halo_from_bottom, value} -> value
    after
      2000 -> throw("Could not receive from bottom")
    end
  end

  def worker(parent, rank, _, _, _, data, _, 0) do
    IO.puts("#{rank}: finished")
    send(parent, {:end_data, rank, data})
  end

  def worker(parent, rank, up, down, top_halo, data, bottom_halo, iters) do
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

  def process_start do
    receive do
      {parent, :start_data,
       {
         rank,
         up,
         down,
         top_halo,
         init_data,
         bottom_halo,
         iters
       }} ->
        worker(parent, rank, up, down, top_halo, init_data, bottom_halo, iters)
    end
  end

  def get_data(x_dim, y_dim) do
    # 2d array of incrementing numbers from 0 to x*y
    # Nx.tensor(Enum.chunk_every(0..(x_dim * y_dim - 1), y_dim), type: :f64)
    Enum.chunk_every(0..(x_dim * y_dim - 1), y_dim)
  end

  def run() do
    # For now, process count == row count
    proc_count = 5
    iters = 10
    IO.puts("start")
    data = NxStencil.get_data(proc_count, 10)

    procs =
      for rank <- 0..(proc_count - 1) do
        {
          rank,
          spawn(&NxStencil.process_start/0)
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
          {self(), :start_data,
           {
             this_rank,
             up,
             down,
             top_halo,
             init_data,
             bottom_halo,
             iters
           }}
        )

        this
      end)

    IO.puts("sent inner")

    {fst_rank, fst} = List.first(procs)
    {lst_rank, lst} = List.last(procs)

    send(
      fst,
      {self(), :start_data,
       {
         fst_rank,
         nil,
         List.first(inner_pids),
         nil,
         Enum.at(data, 0),
         Enum.at(data, 1),
         iters
       }}
    )

    send(
      lst,
      {
        self(),
        :start_data,
        {
          lst_rank,
          List.last(inner_pids),
          nil,
          Enum.at(data, length(data) - 2),
          Enum.at(data, length(data) - 1),
          nil,
          iters
        }
      }
    )

    IO.puts("sent fst, lst")

    IO.puts("Waiting for result")

    for rank <- 0..(proc_count - 1) do
      receive do
        {:end_data, ^rank, data} ->
          IO.puts("from #{rank} -> #{inspect(data)}")
      after
        2000 -> IO.puts("Could not receive from rank #{rank}")
      end
    end
  end
end
