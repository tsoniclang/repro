# Mojo accepts a custom-error coroutine at a native-Error task boundary

A coroutine declared `raises Payload` is accepted by `create_raising_task`,
but its two-field error formats as only `category` after `wait()`.

The [task implementation](https://github.com/modular/modular/blob/2b47eeef01fd2d85269184ced847dc75d2c5040a/Mojo/stdlib/std/runtime/_asyncrt.mojo#L326-L451)
uses native `Error`, not a generic error type. This is a request to reject an
unsupported error combination, not a claim that typed async errors are supported.
The same module explicitly describes its async API as private and unfinished.

## Reproduction

Save as `repro.mojo`:

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

With an activated Mojo SDK, build and run under resource limits:

```bash
mojo build -j 1 -O0 repro.mojo -o repro
./repro
```

**Expected:** reject the unsupported error type at compilation. If it is
supported, preserve the complete formatted error: `category: retained message`.

**Actual:** compilation succeeds; execution exits 1 on the assertion:

```text
left: category
right: category: retained message
```

The final `raise` also makes the program fail if no exception is delivered.
`control.mojo` uses the same payload and assertion with a synchronous function.
It passes, confirming that the formatter writes both fields.

## Verification

Linux x86-64, September 12, 2026; fresh runs of the exact files in this case:

| Mojo SDK | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- |
| `1.1.0.dev2026083005 (ffc874b9)` | Message truncated | Message truncated | Message truncated | Message truncated |
| `1.1.0.dev2026091105 (9b4d4f31)` | Message truncated | Message truncated | Message truncated | Message truncated |

All eight repro builds succeed and executions fail the exact assertion above.
The synchronous control builds and passes in all eight combinations.

Normal native-`Error` async calls and synchronous typed errors are not claimed
to be broken. The inferred task-catch type is `Error`, not `Payload`; losing
custom field access is expected, but accepting an incompatible coroutine and
losing its formatted message is the reported behavior.

## Guarded run from this repository

From the repository root, with Pixi installed:

```bash
pixi install --locked --manifest-path tools/mojo-repro/pixi.toml
pixi run --locked --manifest-path tools/mojo-repro/pixi.toml \
  bash repos/mojo-async-typed-error-payload-loss/reproduce.sh
```

This installs the first SDK listed above. With another activated SDK, run
`bash reproduce.sh` from this case directory. The runner requires Linux, Bash,
GNU `timeout`, and a systemd user manager. It checks O0–O3, retains commands,
hashes and logs under `.temp/`, and returns 1 when a case fails. Limits: 3 GiB
memory, no swap, no core dumps, 45 seconds per build and 10 seconds per execution.
