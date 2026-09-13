# Custom-error coroutine loses part of its message through the public task API

A coroutine declared `raises Payload` is accepted by the documented public
`std.runtime.asyncrt.create_raising_task` API in Mojo 1.0.0. After `wait()` raises,
its two-field error formats as only `category`, losing `retained message`.
The synchronous control preserves both fields.

The [API reference](https://mojolang.org/docs/std/runtime/asyncrt/create_raising_task/) documents the task function. Its
[1.0.0 implementation](https://github.com/modular/modular/blob/mojo/v1.0.0/mojo/stdlib/std/runtime/asyncrt.mojo) uses native `Error` storage, so the report asks
for rejection of an incompatible custom-error coroutine or correct conversion.
It does not assume arbitrary typed async errors are supported. Mojo separately
[classifies async/await as unstable](https://mojolang.org/docs/api-docs/stability/#asyncawait-is-unstable).

The [revised issue draft](ISSUE.md) includes the title and form fields.
See [filing status](../../FILING.md).

## Reproduction

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

With Mojo 1.0.0 activated:

```bash
mojo build -j 1 -O0 repro.mojo -o repro
./repro
```

**Expected:** reject an incompatible custom-error coroutine at compilation.
If conversion to native `Error` is intended to be supported, preserve its full
formatted message: `category: retained message`.

**Actual:** compilation succeeds; execution exits 1 on this assertion:

```text
left: category
right: category: retained message
```

`control.mojo` uses the same payload and assertion synchronously. It passes.
The final `raise` also makes either program fail if no exception is delivered.

## Verification

Ubuntu 26.04.1 LTS, Linux x86-64, AMD Ryzen 9 5900X; September 13, 2026.

| SDK and distribution | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- |
| Wheel `1.0.0 (ed45d567)` | Message truncated | Message truncated | Message truncated | Message truncated |
| Conda `1.0.0 (ed45d567)`, `release` build | Message truncated | Message truncated | Message truncated | Message truncated |

All eight repro builds succeed and executions exit 1 on the assertion above.
The synchronous control builds and exits 0 at all four levels on both SDKs.
These results use the current public import. Earlier nightly results used a
private import and are not evidence for the current source.

## Guarded run

With Mojo 1.0.0 on `PATH`, from the repository root:

```bash
bash repos/mojo-async-typed-error-payload-loss/reproduce.sh
```

Alternatively, use the repository's environment pinned to the release:

```bash
pixi install --locked --manifest-path tools/mojo-repro/pixi.toml
pixi run --locked --manifest-path tools/mojo-repro/pixi.toml \
  bash repos/mojo-async-typed-error-payload-loss/reproduce.sh
```

The runner checks O0–O3 and retains logs under `.temp/`. It requires Linux,
Bash, GNU `timeout`, and a systemd user manager. Limits: 3 GiB memory, no swap
or core dumps, 45 seconds per build, and 10 seconds per execution.
