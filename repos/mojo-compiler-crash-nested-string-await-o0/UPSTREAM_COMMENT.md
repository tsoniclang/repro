An additional minimal async compiler repro: a nested String-returning task
fails compilation at O0–O2 and builds and prints `hello` at O3. This example
uses top-level functions with no arguments, captures, or unsafe code. It may
help distinguish the lowering failure from problems specific to closures.
I have not established whether it shares a root cause with the cases above.

I understand that `std.runtime._asyncrt` is private and unfinished. A source
diagnostic for unsupported usage would be acceptable; the observed results
are a compiler crash dump or internal IR-verification failures.

### Repro

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

With one of the nightly SDKs below activated, the compiler command is:

```bash
mojo build -j 1 -O0 repro.mojo -o repro
```

Repeat at O1–O3. Run `./repro` after a successful build.

### Observed results

Ubuntu 26.04.1 LTS, Linux x86-64, AMD Ryzen 9 5900X; verified September 12–13, 2026.

| SDK and distribution | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- |
| Conda `1.1.0.dev2026083005 (ffc874b9)`, `release` build | Heap-corruption crash dump, then timeout (exit 124) | Invalid IR (exit 1) | Invalid IR (exit 1) | Prints `hello` |
| Wheel `1.1.0.dev2026091105 (9b4d4f31)` | Invalid IR (exit 1) | Invalid IR (exit 1) | Invalid IR (exit 1) | Prints `hello` |

The Conda O0 log begins:

```text
corrupted size vs. prev_size
Please submit a bug report to https://github.com/modular/modular/issues and include the crash backtrace along with all the relevant source codes.
Stack dump:
```

It then prints the compiler invocation and reaches the guarded runner's
45-second build timeout. No executable is produced. The exit status is from
the timeout, so I am not claiming a particular original crash signal.

The IR failures include these diagnostics, abbreviated here to omit the long
generated types:

```text
_coroutine.mojo:36:20: error: 'pop.store' op operand #1 must be parameterized pointer type, but got '!kgen.generator<...>'
_coroutine.mojo:38:13: error: 'pop.load' op operand #0 must be parameterized pointer type, but got '!kgen.generator<...>'
_coroutine.mojo:38:13: error: operand #0 does not dominate this use
error: failed to produce an archive for the module: failed to lower module to LLVM IR for archive compilation, run LowerToLLVMPipeline failed
```

The synchronous control below builds and prints `hello` at every optimization
level on both nightly SDKs:

```mojo
def read() raises -> String:
    return String("hello")

def outer() raises -> String:
    return read()

def main() raises:
    print(outer())
```

### Environment setup

The Conda SDK was installed from `https://conda.modular.com/max-nightly/`
using a Pixi lockfile pinned to `mojo ==1.1.0.dev2026083005`.
The wheel SDK can be installed in a new directory with:

```bash
uv venv
source .venv/bin/activate
uv pip install 'mojo==1.1.0.dev2026091105' \
  --index https://whl.modular.com/nightly/simple/ --prerelease allow
```

Each test used a fresh compiler cache, `-j 1`, a 3 GiB memory limit, no swap
or core dumps, a 45-second build timeout, and a 10-second execution timeout.
Stable `1.0.0 (ed45d567)` lacks `_asyncrt`, so the unchanged repro stops at an
import error on that version.
