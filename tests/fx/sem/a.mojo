def add(a: Int, b: Int) -> Int:
    var s = a + b
    while s > 10:
        s -= 1
    return s

struct P:
    var x: Int
    def get(self) -> Int:
        if self.x > 0 and self.x < 9:
            return self.x
        return 0
