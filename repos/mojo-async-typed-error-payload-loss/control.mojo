from std.testing import assert_equal, assert_true


@fieldwise_init
struct Payload(Copyable, Writable):
    var tag: String
    var message: String

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.tag, ": ", self.message)


def direct() raises Payload -> Int:
    raise Payload("category", "retained message")


def main() raises:
    var rejected = False
    try:
        _ = direct()
    except error:
        assert_equal(String(error), "category: retained message")
        rejected = True
    assert_true(rejected)
