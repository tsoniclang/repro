# [BUG] create_raising_task accepts a custom-error coroutine and loses part of its message

## Bug description

An async function declared `raises Payload` is accepted by
`std.runtime._asyncrt.create_raising_task`. After `wait()` raises, formatting the
caught error produces only `category`, although the original two-field payload
formats as `category: retained message`. The corresponding synchronous program
preserves the complete message.

The [task implementation](https://github.com/modular/modular/blob/2b47eeef01fd2d85269184ced847dc75d2c5040a/Mojo/stdlib/std/runtime/_asyncrt.mojo#L267-L409)
uses native `Error` storage. Its error type is not parameterized. The module
also explicitly describes the async API as private and unfinished. I am
reporting the missing rejection of an unsupported error combination; I am not
assuming that arbitrary typed async errors are supported.

**Actual:** compilation succeeds, and execution exits 1 at the assertion:

```text
AssertionError: `left == right` comparison failed:
   left: category
  right: category: retained message
```

**Expected:** reject an incompatible `raises Payload` coroutine at compilation.
If conversion to a native `Error` is intended to be supported, preserve its
complete formatted message.

## Steps to reproduce

Use a tested nightly SDK. For example, in a new directory with `uv` installed:

```bash
uv venv
source .venv/bin/activate
uv pip install 'mojo==1.1.0.dev2026091105' \
  --index https://whl.modular.com/nightly/simple/ --prerelease allow
mojo --version
```

Save this exact source as `repro.mojo`:

```mojo
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
```

Build and execute:

```bash
mojo build -j 1 -O0 repro.mojo -o repro
./repro
```

Repeat with `-O1`, `-O2`, or `-O3`: the same assertion fails.

This synchronous control builds and exits 0 at all four levels:

```mojo
from std.testing import assert_equal

@fieldwise_init
struct Payload(Copyable, Writable):
    var tag: String
    var message: String

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.tag, ": ", self.message)

def deferred() raises Payload -> Int:
    raise Payload("category", "retained message")

def main() raises:
    try:
        _ = deferred()
    except error:
        assert_equal(String(error), "category: retained message")
        return
    raise Error("expected an exception")
```

## System information

Ubuntu 26.04.1 LTS, Linux x86-64, AMD Ryzen 9 5900X.
Verified September 12–13, 2026, using the same source files throughout.

| SDK | Installation | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- | --- |
| `Mojo 1.1.0.dev2026083005 (ffc874b9)` | Conda, `release` build from `https://conda.modular.com/max-nightly/`, locked with Pixi | Truncated message | Truncated message | Truncated message | Truncated message |
| `Mojo 1.1.0.dev2026091105 (9b4d4f31)` | Wheel from `https://whl.modular.com/nightly/simple/`, uv environment with Python 3.14.4 | Truncated message | Truncated message | Truncated message | Truncated message |

All eight repro builds succeed and all eight executions exit 1 on the assertion
above. All eight synchronous controls build and exit 0. The guarded test runs
used fresh caches, one compiler job, a 3 GiB memory limit, no swap/core dumps,
45 seconds per build, and 10 seconds per execution.

Stable `Mojo 1.0.0 (ed45d567)` cannot exercise this repro because it lacks the
private `_asyncrt` module. Its synchronous control passes at O0–O3.
