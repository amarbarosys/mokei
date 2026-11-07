def used(x):
    return x + 1

def unused(x):
    return x

def _private():
    return 0

class K:
    def method(self):
        return 1

def main():
    print(used(1))
