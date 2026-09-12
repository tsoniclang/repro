from std.runtime._asyncrt import create_raising_task

async def read() raises -> String:
    return String("hello")

async def outer() raises -> String:
    return await create_raising_task(read())

def main() raises:
    var task = create_raising_task(outer())
    print(task^.wait())
