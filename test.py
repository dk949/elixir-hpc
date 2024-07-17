ITERS = 10
X = 5
Y = 10
def get_arr(x_dim, y_dim):
    return [[float(x * y_dim + y) for y in range(y_dim)] for x in range (x_dim)]

def empty(x_dim, y_dim):
    return [[float(0) for _ in range(y_dim)] for _ in range (x_dim)]

def access(arr, x, y):
    if x < 0 or x > X -1 or y < 0 or y > Y - 1: return 0.0
    else: return arr[x][y]

data1 = get_arr(X, Y)
data2 = empty(X, Y)

for i in range(ITERS):
    for x in range(X):
        for y in range(Y):
            data2[x][y] =(
                access(data1, x - 1, y-1) +access(data1, x, y-1) +access(data1, x + 1, y-1)  +
                access(data1, x - 1, y) +access(data1, x, y) +access(data1, x + 1, y)  +
                access(data1, x - 1, y+1) +access(data1, x, y+1) +access(data1, x + 1, y+1)
                ) / 9
    data1, data2 = data2, data1

if not (ITERS % 2):
    data1, data2 = data2, data1

for i,row in enumerate(data2):
    print(f"from {i} -> {row}")
