# Mojo compiler segfaults at O0 on a nested String-returning task

Compiling this program at O0 crashes the compiler before it produces an
executable. The program has no function arguments, captures, or unsafe code.

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

**Actual:** compiler SIGSEGV (exit 139), a native stack dump, and no executable.
The crash header asks for a bug report. At O1/O2, compilation instead fails
native `pop.store`/`pop.load` IR verification (exit 1). At O3, the same input
builds and prints `hello` on both tested SDKs.

## Verification

Linux x86-64, September 12, 2026:

| Mojo SDK | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- |
| `1.1.0.dev2026083005 (ffc874b9)` | Compiler SIGSEGV | Invalid native IR | Invalid native IR | Prints `hello` |
| `1.1.0.dev2026091105 (9b4d4f31)` | Compiler SIGSEGV | Invalid native IR | Invalid native IR | Prints `hello` |

`control.mojo` removes only async/task execution and retains the same nested
String-returning calls. It builds and prints `hello` in all eight SDK/level
combinations. These results are from fresh runs of the exact files in this case.
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
