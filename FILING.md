# Filing status

Only the typed-error case currently has a failure reproduced through a
public API. The compiler-report recommendation is withdrawn.

| Case | Public API result on Mojo 1.0.0 wheel and Conda | Action |
| --- | --- | --- |
| Custom-error coroutine passed to `create_raising_task` | Builds, then loses part of the error message at O0–O3 | Use the [revised issue draft](repos/mojo-async-typed-error-payload-loss/ISSUE.md) if reporting the missing diagnostic or conversion |
| Nested String-returning async task | Builds and prints `hello` at O0–O3 | Do not post the previous compiler-failure comment on #6842 |

Both current repros import `std.runtime.asyncrt`, documented in the
[Mojo 1.0.0 API reference](https://mojolang.org/docs/std/runtime/asyncrt/create_raising_task/). No current repro imports a private module.
Public availability does not imply a stability guarantee: Mojo explicitly
[classifies async/await as unstable](https://mojolang.org/docs/api-docs/stability/#asyncawait-is-unstable).

## Typed-error report

Open the [Mojo bug-report form](https://github.com/modular/modular/issues/new?template=mojo_bug_report.yaml).
Use the title from [ISSUE.md](repos/mojo-async-typed-error-payload-loss/ISSUE.md)
and copy its **Bug description**, **Steps to reproduce**, and
**System information** into the matching form fields.

The report asks for rejection of an incompatible custom-error coroutine or
correct conversion to native `Error`. It does not assert that arbitrary typed
async errors are supported, or that the experimental async API is stabilized.

## Compiler report withdrawn

The previous recommendation used a nightly-only private module,
`std.runtime._asyncrt`. Those observed failures do not establish a problem with
the current public-API example. With Mojo 1.0.0 and the documented import,
the example and synchronous control both pass at O0–O3.

The [former comment file](repos/mojo-compiler-crash-nested-string-await-o0/UPSTREAM_COMMENT.md)
now records the withdrawal. The existing upstream issue
[#6842](https://github.com/modular/modular/issues/6842) remains an independent
report; these checks do not resolve its cases.

## Verification

The guarded runners save commands, hashes, compiler logs, program output, and
results under `.temp/`. These files are ignored by Git. The current READMEs
record results for the public API; earlier nightly/private-API results remain
in Git history and local evidence directories.

The [public-API verification record](tools/mojo-repro/VERIFICATION.md) includes
source hashes, all 32 build/run results, and the observed assertion.
