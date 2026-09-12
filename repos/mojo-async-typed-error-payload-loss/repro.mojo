from std.runtime._asyncrt import create_raising_task
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Payload(Copyable, Writable):
    var tag: String
    var message: String

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.tag, ": ", self.message)


def direct() raises Payload -> Int:
    raise Payload("category", "retained message")


async def deferred() raises Payload -> Int:
    raise Payload("category", "retained message")


def main() raises:
    var direct_rejected = False
    try:
        _ = direct()
    except error:
        assert_equal(String(error), "category: retained message")
        direct_rejected = True
    assert_true(direct_rejected)
    var deferred_rejected = False
    try:
        _ = create_raising_task(deferred()).wait()
    except error:
        assert_equal(String(error), "category: retained message")
        deferred_rejected = True
    assert_true(deferred_rejected)
