data = [
    0 , 0  , 0  , 0  , 0  , 0  , 0  , 0,
    0 , 0  , 1  , 2  , 3  , 4  , 5  , 0,
    0 , 6  , 7  , 8  , 9  , 10 , 11 , 0,
    0 , 12 , 13 , 14 , 15 , 16 , 17 , 0,
    0 , 18 , 19 , 20 , 21 , 22 , 23 , 0,
    0 , 24 , 25 , 26 , 27 , 28 , 29 , 0,
    0 , 30 , 31 , 32 , 33 , 34 , 35 , 0,
    0 , 0  , 0  , 0  , 0  , 0  , 0  , 0,
  ]
grid_size = 8

for (pos, elem) in enumerate(data):
    gs_1 = grid_size - 1
    gs_sq = (grid_size ** 2) - grid_size
    print(
            (data[pos - grid_size - 1] + data[pos - grid_size] + data[ pos - grid_size + 1] +
             data[pos - 1]             + elem                  + data[pos + 1] +
             data[pos + grid_size - 1] + data[ pos - grid_size] + data[pos + grid_size + 1]) / 9
            )

