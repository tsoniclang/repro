# [BUG] Public create_raising_task accepts a custom-error coroutine and truncates its message

## Bug description

In Mojo 1.0.0, an async function declared `raises Payload` is accepted by the
[documented public `std.runtime.asyncrt.create_raising_task` API](https://mojolang.org/docs/std/runtime/asyncrt/create_raising_task/).
After `wait()` raises, formatting the caught error produces only `category`,
although the original two-field payload formats as
`category: retained message`. The corresponding synchronous program preserves
the complete message. This repro does not import any private module.

The [1.0.0 task implementation](https://github.com/modular/modular/blob/mojo/v1.0.0/mojo/stdlib/std/runtime/asyncrt.mojo) uses native `Error` storage and does
not parameterize the error type. I am reporting acceptance of an incompatible
custom-error coroutine or incorrect conversion to native `Error`.
I understand that [async/await is unstable](https://mojolang.org/docs/api-docs/stability/#asyncawait-is-unstable); this is not a claim
that arbitrary typed async errors have been supported or stabilized.

**Actual:** compilation succeeds, and execution exits 1 at the assertion:

```text
AssertionError: `left == right` comparison failed:
   left: category
  right: category: retained message
```

**Expected:** reject an incompatible `raises Payload` coroutine at compilation.
If conversion to native `Error` is intended to be supported, preserve its
complete formatted message.

## Steps to reproduce

In a new directory with `uv` installed:

```bash
uv venv
source .venv/bin/activate
uv pip install 'mojo==1.0.0'
mojo --version
```

Save this exact source as `repro.mojo`:

```mojo
from std.runtime.asyncrt import create_raising_task
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

The complete repro directory and guarded runner are available at:
https://github.com/tsoniclang/repro/tree/main/repos/mojo-async-typed-error-payload-loss

## System information

Ubuntu 26.04.1 LTS, Linux x86-64, AMD Ryzen 9 5900X.
Verified September 13, 2026, using the public import shown above.

| SDK and distribution | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- |
| Wheel `Mojo 1.0.0 (ed45d567)`, installed from PyPI with uv and Python 3.14.4 | Truncated message | Truncated message | Truncated message | Truncated message |
| Conda `Mojo 1.0.0 (ed45d567)`, `release` build, installed from `https://conda.modular.com/max/` with a Pixi lockfile | Truncated message | Truncated message | Truncated message | Truncated message |

All eight repro builds succeed and all eight executions exit 1 on the assertion
above. All eight synchronous controls build and exit 0. The guarded test runs
used fresh caches, one compiler job, a 3 GiB memory limit, no swap/core dumps,
45 seconds per build, and 10 seconds per execution.
