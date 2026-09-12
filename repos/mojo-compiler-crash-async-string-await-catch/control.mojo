from std.testing import assert_equal, assert_true

def read() raises -> String:
    return String("unchanged")

def write(value: String) raises:
    if value == "bad":
        raise Error("failure")

def operation() raises:
    write("first")
    var first = read()
    assert_equal(first, "unchanged")
    write("last")
    var rejected = False
    try:
        write("bad")
    except:
        rejected = True
    assert_true(rejected)
    var final = read()
    assert_equal(final, "unchanged")

def main() raises:
    operation()
