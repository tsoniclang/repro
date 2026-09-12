from std.runtime._asyncrt import create_raising_task
from std.testing import assert_equal

@fieldwise_init
struct Payload(Copyable, Writable):
    var tag: String
    var message: String

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.tag, ": ", self.message)

async def deferred() raises Payload -> Int:
    raise Payload("category", "retained message")

def main() raises:
    try:
        var task = create_raising_task(deferred())
        _ = task^.wait()
    except error:
        assert_equal(String(error), "category: retained message")
        return
    raise Error("expected an exception")
