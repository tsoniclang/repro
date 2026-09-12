def read() raises -> String:
    return String("hello")

def outer() raises -> String:
    return read()

def main() raises:
    print(outer())
