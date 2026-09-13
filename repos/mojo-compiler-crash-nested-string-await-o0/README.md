# Nested String-returning async task: passes through the public API

The current example imports the documented public `std.runtime.asyncrt`
module from Mojo 1.0.0. It builds and prints `hello` at O0–O3, and its
synchronous control passes at all four levels.

**The previous compiler-report recommendation is withdrawn.** Earlier failures
used a private module on nightly SDKs. They are not results for the current
source, and the current public-API example does not reproduce them.
The directory name is retained to keep existing links working.

## Current example

```mojo
from std.runtime.asyncrt import create_raising_task

async def read() raises -> String:
    return String("hello")

async def outer() raises -> String:
    return await create_raising_task(read())

def main() raises:
    var task = create_raising_task(outer())
    print(task^.wait())
```

`create_raising_task` is listed in the [1.0.0 API reference](https://mojolang.org/docs/std/runtime/asyncrt/create_raising_task/).
Mojo [classifies async/await as unstable](https://mojolang.org/docs/api-docs/stability/#asyncawait-is-unstable); this is a documented
public interface, without a stability guarantee.

## Verification

Ubuntu 26.04.1 LTS, Linux x86-64, AMD Ryzen 9 5900X; September 13, 2026.

| SDK and distribution | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- |
| Wheel `1.0.0 (ed45d567)` | Prints `hello` | Prints `hello` | Prints `hello` | Prints `hello` |
| Conda `1.0.0 (ed45d567)`, `release` build | Prints `hello` | Prints `hello` | Prints `hello` | Prints `hello` |

All repro and control builds and executions exit 0. The only source change
from the previously tested example is the public import path. The SDK also
changed from a nightly to the 1.0.0 release, so these runs do not isolate which
version or implementation change accounts for the different behavior.

## Guarded run

With Mojo 1.0.0 on `PATH`, from the repository root:

```bash
bash repos/mojo-compiler-crash-nested-string-await-o0/reproduce.sh
```

Alternatively, use the repository's environment pinned to the release:

```bash
pixi install --locked --manifest-path tools/mojo-repro/pixi.toml
pixi run --locked --manifest-path tools/mojo-repro/pixi.toml \
  bash repos/mojo-compiler-crash-nested-string-await-o0/reproduce.sh
```

The runner checks O0–O3 and retains logs under `.temp/`. It requires Linux,
Bash, GNU `timeout`, and a systemd user manager. Limits: 3 GiB memory, no swap
or core dumps, 45 seconds per build, and 10 seconds per execution.
