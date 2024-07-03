defmodule SimpleStencil do

  @data [
    0 , 0  , 0  , 0  , 0  , 0  , 0  , 0,
    0 , 0  , 1  , 2  , 3  , 4  , 5  , 0,
    0 , 6  , 7  , 8  , 9  , 10 , 11 , 0,
    0 , 12 , 13 , 14 , 15 , 16 , 17 , 0,
    0 , 18 , 19 , 20 , 21 , 22 , 23 , 0,
    0 , 24 , 25 , 26 , 27 , 28 , 29 , 0,
    0 , 30 , 31 , 32 , 33 , 34 , 35 , 0,
    0 , 0  , 0  , 0  , 0  , 0  , 0  , 0,
  ]


  def enumerate(lst) do
    Enum.zip(lst, Stream.iterate(0, &(&1 + 1)))
  end

  def get_data, do: @data

  defp run_inner(data, curr_iter, total_iters, _) when curr_iter == total_iters do
    data
  end

  defp run_inner(data, curr_iter, total_iters, grid_size) do
    gs_1 = grid_size - 1
    gs_sq = (grid_size ** 2) - grid_size

    run_inner(
      Enum.map(
        enumerate(data),
        fn
          {elem, pos}
          when pos >= gs_1 and
                 pos < gs_sq and
                 rem(pos, grid_size) != 0 and
                 rem(pos, grid_size) != gs_1 ->
            (Enum.at(data, pos - grid_size - 1) + Enum.at(data, pos - grid_size) + Enum.at(data, pos - grid_size + 1) +
             Enum.at(data, pos - 1)             + elem                           + Enum.at(data, pos + 1) +
             Enum.at(data, pos + grid_size - 1) + Enum.at(data, pos - grid_size) + Enum.at(data, pos + grid_size + 1)) / 9

          {elem, _} -> elem
        end
      ),
      curr_iter + 1,
      total_iters,
      grid_size
    )
  end

  def run(iters, out) do
    File.write(out, @data |> run_inner(0, iters, 8) |> inspect(limit: :infinity))
  end
end
