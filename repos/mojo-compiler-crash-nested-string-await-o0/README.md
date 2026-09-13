# Mojo compiler fails at O0–O2 on a nested String-returning task

Compiling this program at O0–O2 fails inside the compiler; O3 builds and prints
`hello`. The O0 failure differs between the tested SDKs. The program has no
function arguments, captures, or unsafe code.

The prepared [upstream comment](UPSTREAM_COMMENT.md) can be posted on the related
async compiler report [#6842](https://github.com/modular/modular/issues/6842).

Mojo's async runtime is [private and unfinished](https://github.com/modular/modular/blob/2b47eeef01fd2d85269184ced847dc75d2c5040a/Mojo/stdlib/std/runtime/_asyncrt.mojo#L13-L20).
This report concerns a compiler crash, not a promise of public async support.
A source diagnostic would be acceptable if this combination is unsupported.

## Reproduction

Save as `repro.mojo`:

```mojo
from std.runtime._asyncrt import create_raising_task

async def read() raises -> String:
    return String("hello")

async def outer() raises -> String:
    return await create_raising_task(read())

def main() raises:
    var task = create_raising_task(outer())
    print(task^.wait())
```

With an activated Mojo SDK, compile under resource limits:

```bash
mojo build -j 1 -O0 repro.mojo -o repro
```

**Expected:** compilation succeeds and the program prints `hello`, or unsupported
usage receives a source diagnostic.

**Actual:** the locked Conda SDK at O0 reports `corrupted size vs. prev_size`,
asks for a bug report, and begins a stack dump. The guarded run then reaches
its 45-second timeout (exit 124), with no executable. This does not establish
the original crash signal. The newer nightly wheel SDK at O0 instead fails
native `pop.store`/`pop.load` IR verification (exit 1).

Both SDKs fail IR verification at O1/O2 and build and print `hello` at O3.

## Verification

Ubuntu 26.04.1 LTS, Linux x86-64, AMD Ryzen 9 5900X; September 12–13, 2026:

| Mojo SDK and distribution | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- |
| Conda `1.1.0.dev2026083005 (ffc874b9)` | Heap-corruption crash dump, then timeout (124) | Invalid native IR (1) | Invalid native IR (1) | Prints `hello` |
| Wheel `1.1.0.dev2026091105 (9b4d4f31)` | Invalid native IR (1) | Invalid native IR (1) | Invalid native IR (1) | Prints `hello` |

`control.mojo` removes only async/task execution and retains the same nested
String-returning calls. It builds and prints `hello` in all eight SDK/level
combinations. These results are from fresh runs of the exact files in this case.
The previously reported O0 SIGSEGV/exit 139 was not reconfirmed. Stable wheel
`1.0.0 (ed45d567)` lacks `_asyncrt`, so the unchanged repro fails to import at
every optimization level; its synchronous control passes at every level.

Related async lowering failures are tracked in
[issue #6842](https://github.com/modular/modular/issues/6842); a shared internal
cause has not been established.

## Guarded run from this repository

From the repository root, with Pixi installed:

```bash
pixi install --locked --manifest-path tools/mojo-repro/pixi.toml
pixi run --locked --manifest-path tools/mojo-repro/pixi.toml \
  bash repos/mojo-compiler-crash-nested-string-await-o0/reproduce.sh
```

This installs the first SDK listed above. With another activated SDK, run
`bash reproduce.sh` from this case directory. The runner requires Linux, Bash,
GNU `timeout`, and a systemd user manager. It checks O0–O3, retains commands,
hashes and logs under `.temp/`, and returns 1 when a case fails. Limits: 3 GiB
memory, no swap, no core dumps, 45 seconds per build and 10 seconds per execution.
