# Mojo compiler crashes on String awaits around try/catch

**Report classification:** compiler robustness failure in Mojo's unfinished,
private async machinery, not a regression in a supported public async API.
The [upstream module contract](https://github.com/modular/modular/blob/2b47eeef01fd2d85269184ced847dc75d2c5040a/Mojo/stdlib/std/runtime/_asyncrt.mojo#L13-L20)
explicitly says applications should not depend on this runtime. That limitation
must accompany this report, not be omitted when filing it.

[repro.mojo](repro.mojo) awaits String-returning tasks, catches a failing awaited
call, then awaits another String result. It imports only the Mojo standard
library, including its `std.runtime._asyncrt` task API. No Tsonic, generated code,
custom runtime, FFI, filesystem or network is involved.

For a supported implementation, compilation would succeed and every assertion
would pass with exit 0. If the input uses an unsupported combination, a source
diagnostic is an acceptable outcome; the robustness issue is crashing or failing
native IR verification instead.
Observed on Linux x86-64: the native compiler fails before producing an executable
at **all four optimization levels**, including O0.

[control.mojo](control.mojo) performs the same operations synchronously, retaining
the String values, deliberate failure, catch and subsequent successful call.
It removes only async/task/await execution and is expected to pass at every level.

## What the program does

1. Await a successful write-like function.
2. Await a function returning the owned String `"unchanged"`; verify that value.
3. Await another successful call.
4. Await a call that deliberately raises native `Error("failure")` inside a
   try/catch; verify that the catch actually ran.
5. Await another String result after the catch; verify its value again.

`main` waits for the outer native task. There are no unconsumed tasks or manually
managed pointers in the input. The compiler, not the example, is responsible for
coroutine transformation. The synchronous control retains the same successful
calls, error branch, catch and post-catch assertion without suspension.

We encountered this while checking asynchronous file-content operations in a
TypeScript-to-Mojo application: sequential writes/reads, a failing awaited call,
and a subsequent successful read. The standalone program replaces all filesystem
operations with literal/String-returning functions. It does not require the
application or its compiler to reproduce the failure.

## Reproduce

Requirements: Linux x86-64, Bash, GNU `timeout`, `sha256sum`, a systemd user manager
with memory-controller support, and Pixi. Run from the repository root:

```bash
pixi install --locked --manifest-path tools/mojo-repro/pixi.toml
pixi run --locked --manifest-path tools/mojo-repro/pixi.toml \
  bash repos/mojo-compiler-crash-async-string-await-catch/reproduce.sh
```

The shared manifest and lock pin `Mojo 1.1.0.dev2026083005 (ffc874b9)`.
To compare another already-activated SDK, put its `mojo` on PATH with its usual
activation environment and run `bash reproduce.sh` from this directory.

The runner tries both files at O0, O1, O2 and O3, continuing after failures.
It exits 1 if any build/run fails. It prints a retained `.temp/` evidence directory
containing exact commands, SDK/source hashes, build/run logs and `results.tsv`.
It never deletes results or reuses a previous executable after a build failure.

Resource bounds: 3 GiB total memory, zero swap, no core dumps, 96 tasks, a
10-minute outer deadline, 45 seconds per build and 10 seconds per execution.
It does not run unguarded if the systemd user manager is unavailable.

For compiler-owner debugging, the essential invocation inside an appropriate
resource guard is `mojo build -j 1 -O0 repro.mojo -o <scratch-output>`.

## Verified failure and limits

The exact repro was independently tested on September 12, 2026:

| SDK | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- |
| `1.1.0.dev2026083005 (ffc874b9)` | Build SIGSEGV | Build SIGSEGV | Timeout after crash-report header | Build SIGSEGV |
| `1.1.0.dev2026091105 (9b4d4f31)` | Build SIGSEGV | Timeout after crash-report header | Build SIGSEGV | Build SIGSEGV |

Those initial matrix builds used 35-second deadlines. SIGSEGV exits were 139;
timeouts were 124, not claimed as SIGSEGV exit statuses. Neither timeout produced
an executable. Exact crash reporting can vary between runs; the separate retained
logs establish which command exited or timed out.

Rechecking this packaged copy also produces native IR verification errors such
as `pop.pointer.bitcast` receiving `i64` instead of a pointer and an invalid
`pop.store` operand. These are compiler-generated native IR failures, not source
type errors. The same unchanged input can therefore produce a SIGSEGV, fail
native lowering, or stall in crash reporting. The observed constant is failure
to produce a working program at every tested level, not one deterministic
backtrace or exit status.

The packaged synchronous control was also freshly built and run at O0–O3 on
both SDKs: **8/8 controls pass**. The corresponding **8/8 async repro builds
fail**. All levels run even after an earlier failure, with separate caches and
unchanged source hashes. The packaged guards peak below 200 MiB with no swap.

This is not the earlier borrowed-String variadic issue: that program builds and
its optimized executable crashes, while O0 passes. This example fails during
compilation even at O0. No common internal compiler cause is asserted.

The input uses the SDK's internal `std.runtime._asyncrt` task API explicitly;
we are not presenting it as a stable public library contract. If a combination
is unsupported, a deterministic source diagnostic would be preferable to a
compiler crash. The exact compiler pass or memory-corruption mechanism has not
been established by this reduction and is left for upstream diagnosis.

The initial matrix peaked below 363 MiB with no swap, far below its 3 GiB ceiling.
No optimizer setting, removed catch, custom coroutine transform or application
workaround is being proposed. Other platforms and untested SDKs are not certified.

## Skeptical contract audit

The task is consumed exactly once through `wait` or `await`; the example does
not call unchecked `get`, destroy incomplete tasks, or manipulate coroutine
handles. This follows the consumption pattern in the
[upstream raising-task tests](https://github.com/modular/modular/blob/2b47eeef01fd2d85269184ced847dc75d2c5040a/Mojo/stdlib/test/runtime/test_raising_asyncrt.mojo#L119-L165).
That establishes the intended internal usage, not public API stability.

Additional September 12 checks on both SDKs at O0 and O3 removed **all function
arguments**, used named tasks, and transferred each task explicitly. Compilation
still crashed or timed out after a native crash header. Thus the original
failure is not explained solely by borrowed String arguments or unnamed tasks.
Removing the catch also still failed: the title describes the supplied source,
not a proof that `try`/`except` is the unique necessary trigger. Replacing inner
tasks with direct coroutine awaits produced native IR failures, including
`pop.cast_from_builtin` bool casts and invalid `pop.store` operands, rather than
a working executable.

Three other diagnostic variants that changed arguments to owned temporary
Strings were rejected with uninitialized-value source diagnostics. Those
rejections are **not** counted as confirmation of this compiler crash.

[Upstream issue #6842](https://github.com/modular/modular/issues/6842) already
reports related unfinished async lowering failures, including the bool-cast
diagnostic. Check that issue before filing; this reduction is not a claim of a
new or internally distinct bug. It uses no capturing closures, but only the
compiler owner can establish whether its underlying cause is the same.
