from std.runtime._asyncrt import create_raising_task
from std.testing import assert_equal, assert_true

async def read() raises -> String:
    return String("unchanged")

async def write(value: String) raises:
    if value == "bad":
        raise Error("failure")

async def operation() raises:
    await create_raising_task(write("first"))
    var first = await create_raising_task(read())
    assert_equal(first, "unchanged")
    await create_raising_task(write("last"))
    var rejected = False
    try:
        await create_raising_task(write("bad"))
    except:
        rejected = True
    assert_true(rejected)
    var final = await create_raising_task(read())
    assert_equal(final, "unchanged")

def main() raises:
    var task = create_raising_task(operation())
    task^.wait()
