# Missing rejection of typed async errors at a native-Error task boundary

**Report classification:** an unsupported typed-error combination is accepted
and executes with the wrong observable message. This is **not** evidence that
Mojo promises general typed async exception support or that a supported public
API regressed. The
[upstream module contract](https://github.com/modular/modular/blob/2b47eeef01fd2d85269184ced847dc75d2c5040a/Mojo/stdlib/std/runtime/_asyncrt.mojo#L13-L20)
explicitly calls this runtime unfinished and private and says applications should
not depend on it. The narrowly justified upstream request is to diagnose the
unsupported error boundary, not to promise a new async capability.

[repro.mojo](repro.mojo) throws the same two-field native `Payload` synchronously
and asynchronously. The synchronous catch verifies `category: retained message`.
The awaited catch instead receives a value formatting as only `category`.

It imports only Mojo's standard library, including `std.runtime._asyncrt`.
There is no Tsonic, generated source, FFI, custom scheduler or variadic-forwarding
helper. The same repro includes its own synchronous control; the separate
[control.mojo](control.mojo) also verifies that path independently.

## What the program does

`Payload` has two owned String fields: `tag` and `message`. Its native formatter
writes both separated by `": "`. The ordinary `direct()` function and native
`async def deferred()` construct and raise the same payload. `main` catches the
direct call first, then the native task returned by `create_raising_task` and
consumed with `wait()`. Flags prove that both expected error paths actually run;
the assertions cannot pass merely because a throw was omitted.

We found this while testing a retained TypeScript async callback containing
`throw new Error("negative step")`. Its exact source error carrier was not native
Mojo `Error`. The native await lost the message, so the target now rejects that
unsafe mapping rather than shipping it. This standalone program removes that
target, its source error carrier and all runtime adapters; two ordinary native
String fields reproduce the same class of loss.

## Expected versus actual

- If typed errors are supported across this boundary, preserve the exact payload.
- If they are not supported, reject the incompatible combination at compilation.
- Do not successfully compile and then interpret the payload as a different error
  representation. The existing native coroutine/task await API uses native `Error`;
  this report does not assume that generic typed async exceptions are already a
  documented capability.

Actual execution on both tested SDKs fails the retained-message assertion:

```text
left: category
right: category: retained message
```

This is an accepted-program payload-loss report, not a compiler-process crash.
Safety rejection would resolve incorrect acceptance; adding actual typed-await
support is a distinct capability request.

## Reproduce

Requirements: Linux x86-64, Bash, GNU `timeout`, `sha256sum`, a systemd user manager
with memory-controller support, and Pixi. Run from the repository root:

```bash
pixi install --locked --manifest-path tools/mojo-repro/pixi.toml
pixi run --locked --manifest-path tools/mojo-repro/pixi.toml \
  bash repos/mojo-async-typed-error-payload-loss/reproduce.sh
```

The shared manifest and lock pin `Mojo 1.1.0.dev2026083005 (ffc874b9)`.
To test another already-activated SDK, use its `mojo` on PATH with its usual
activation environment and run `bash reproduce.sh` from this directory.

The runner builds/runs both files at O0, O1, O2 and O3 without stopping after
the first failure. Its expected status on the affected SDKs is 1, preserving the
actual failing assertions rather than declaring bug reproduction a passing run.
It prints the retained `.temp/` directory containing SDK/source hashes, commands,
logs and `results.tsv`. Failed builds never run stale executables.

Resource bounds: 3 GiB total memory, zero swap, no core dumps, 96 tasks, a
10-minute outer deadline, 45 seconds per build and 10 seconds per execution.
There is no unguarded execution fallback.

The essential compiler-owner invocation inside a suitable guard is
`mojo build -j 1 -O0 repro.mojo -o <scratch-output>`, followed by executing it.

## Verified September 12, 2026

| SDK | O0 | O1 | O2 | O3 |
| --- | --- | --- | --- | --- |
| `1.1.0.dev2026083005 (ffc874b9)` | Payload lost | Payload lost | Payload lost | Payload lost |
| `1.1.0.dev2026091105 (9b4d4f31)` | Payload lost | Payload lost | Payload lost | Payload lost |

All eight repro builds succeed. Every execution exits 1 on the same assertion;
the synchronous check within each repro succeeds first. This rules out an
optimization-only problem for the tested program and SDKs. It does not establish
the first affected revision, all possible payload layouts, or other platforms.

The packaged independent synchronous control also passes **8/8 builds and runs**
across both SDKs and all four levels. The **8/8 awaited repro executions fail**
the exact payload assertion. The same packaged runner completes every case under
its guards, below 200 MiB peak memory with no swap.

This reproduction is independent of the async String compilation failure and
the earlier variadic executable crash; no shared internal root cause is claimed.

The task API is explicitly the internal `std.runtime._asyncrt` API supplied by
the SDK. The observation proves incorrect accepted behavior for this input,
not a promise that arbitrary typed async exceptions are already supported.
No field casts, source-name recovery, exception stringification workaround or
native compiler patch is proposed. The exact internal fix remains upstream work.

## Skeptical contract audit

The upstream
[RaisingCoroutine](https://github.com/modular/modular/blob/2b47eeef01fd2d85269184ced847dc75d2c5040a/Mojo/stdlib/std/builtin/_coroutine.mojo#L197-L304)
type has result/origin parameters but no error-type parameter. Its error slot
and `__await__` implementation use native `Error`.
[RaisingTask](https://github.com/modular/modular/blob/2b47eeef01fd2d85269184ced847dc75d2c5040a/Mojo/stdlib/std/runtime/_asyncrt.mojo#L326-L451)
also allocates an `Error` slot and exposes bare-`raises` `wait`/`__await__` methods.
The custom error declared on `deferred` therefore does not have a corresponding
typed task transport in this implementation.

A fresh probe added compile-time assertions: the synchronous catch infers
`Payload`, while the task catch infers **`Error`**, not `Payload`. It still
compiled and failed the same message assertion on both SDKs at O0 and O3.
This distinction matters: absence of `Payload` fields on the caught value is
expected from the task's signature and is not itself the reported defect.

Three additional controls passed at O0 and O3 on both SDKs:

- Raise native `Error("category: retained message")` asynchronously and check its
  message after task consumption.
- Catch `Payload` from a synchronous call inside the async function, verifying
  its fields' formatted output before any error crosses the task boundary.
- Propagate that synchronous typed error through a bare-`raises` wrapper, both
  synchronously and asynchronously; ordinary conversion to native `Error`
  preserves `category: retained message` in both cases.

For example, the third control's async wrapper is:

```mojo
async def deferred() raises -> Int:
    return direct()
```

These are diagnostic controls, not a proposed Tsonic workaround. They show that
the failed assertion is not merely the normal loss of custom field access when
converting a typed error to `Error`. The mismatching case specifically declares
the coroutine itself as `raises Payload` and passes it to the native-Error-only
task machinery without a rejecting diagnostic.

Directly awaiting that custom-error coroutine inside an outer native-Error
coroutine also failed native lowering in further probes; it did not demonstrate
an alternative supported typed-await path. The exact internal fix, support
roadmap, severity and duplicate status remain for upstream triage. The report
does not claim that arbitrary custom error layouts are supported or that the
observed output alone proves a particular memory-corruption mechanism.
