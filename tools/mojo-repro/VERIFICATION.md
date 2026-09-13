# Public API verification — September 13, 2026

Both examples use `from std.runtime.asyncrt import create_raising_task`,
the documented public interface in Mojo 1.0.0. Async behavior is still
classified as unstable. The private nightly module is not used.

Environment: Ubuntu 26.04.1 LTS, Linux x86-64, AMD Ryzen 9 5900X.
Both SDKs report `Mojo 1.0.0 (ed45d567)`: the wheel installed from PyPI
with uv, and the Conda release installed with the adjacent Pixi lockfile.

The existing guarded runner was used with fresh per-case compiler caches,
one compiler job, a 3 GiB memory limit, no swap or core dumps, a 45-second
build timeout, and a 10-second execution timeout.

All 16 synchronous controls pass. The nested String example passes at all
four levels on both SDKs. The typed-error example builds at all levels,
then exits 1 because the message is truncated.

## Results

| SDK | Example | Case | Optimization | Build exit | Run exit |
| --- | --- | --- | --- | --- | --- |
| Wheel | Nested String | control | O0 | 0 | 0 |
| Wheel | Nested String | control | O1 | 0 | 0 |
| Wheel | Nested String | control | O2 | 0 | 0 |
| Wheel | Nested String | control | O3 | 0 | 0 |
| Wheel | Nested String | repro | O0 | 0 | 0 |
| Wheel | Nested String | repro | O1 | 0 | 0 |
| Wheel | Nested String | repro | O2 | 0 | 0 |
| Wheel | Nested String | repro | O3 | 0 | 0 |
| Wheel | Typed error | control | O0 | 0 | 0 |
| Wheel | Typed error | control | O1 | 0 | 0 |
| Wheel | Typed error | control | O2 | 0 | 0 |
| Wheel | Typed error | control | O3 | 0 | 0 |
| Wheel | Typed error | repro | O0 | 0 | 1 |
| Wheel | Typed error | repro | O1 | 0 | 1 |
| Wheel | Typed error | repro | O2 | 0 | 1 |
| Wheel | Typed error | repro | O3 | 0 | 1 |
| Conda | Nested String | control | O0 | 0 | 0 |
| Conda | Nested String | control | O1 | 0 | 0 |
| Conda | Nested String | control | O2 | 0 | 0 |
| Conda | Nested String | control | O3 | 0 | 0 |
| Conda | Nested String | repro | O0 | 0 | 0 |
| Conda | Nested String | repro | O1 | 0 | 0 |
| Conda | Nested String | repro | O2 | 0 | 0 |
| Conda | Nested String | repro | O3 | 0 | 0 |
| Conda | Typed error | control | O0 | 0 | 0 |
| Conda | Typed error | control | O1 | 0 | 0 |
| Conda | Typed error | control | O2 | 0 | 0 |
| Conda | Typed error | control | O3 | 0 | 0 |
| Conda | Typed error | repro | O0 | 0 | 1 |
| Conda | Typed error | repro | O1 | 0 | 1 |
| Conda | Typed error | repro | O2 | 0 | 1 |
| Conda | Typed error | repro | O3 | 0 | 1 |

## Observed typed-error assertion

The following excerpt is present in all eight failing executions:

```text
AssertionError: `left == right` comparison failed:
   left: category
  right: category: retained message
```

## Source hashes

| Source | SHA-256 |
| --- | --- |
| `repos/mojo-compiler-crash-nested-string-await-o0/repro.mojo` | `e8c1ca7af4612e9fb1541967dee8e7736f7f8648ca3c810e340aedaa846e3951` |
| `repos/mojo-compiler-crash-nested-string-await-o0/control.mojo` | `1c1bbc96d9a36c3279e4138da95bcc5e8a60d15a8ff48b0b411349a3f2ff40e9` |
| `repos/mojo-async-typed-error-payload-loss/repro.mojo` | `77ba8032a2a9c78f6ded4efd9eac3e300774c14d5adc6f7731653671b2c2a4c9` |
| `repos/mojo-async-typed-error-payload-loss/control.mojo` | `0f6f88799722246d030b0dd9b29fdf478be7e069bca471e7dd8e582507ac4050` |

## Reproduce

With the release environment installed:

```bash
pixi install --locked --manifest-path tools/mojo-repro/pixi.toml
pixi run --locked --manifest-path tools/mojo-repro/pixi.toml \
  bash repos/mojo-compiler-crash-nested-string-await-o0/reproduce.sh
pixi run --locked --manifest-path tools/mojo-repro/pixi.toml \
  bash repos/mojo-async-typed-error-payload-loss/reproduce.sh
```

The compiler-example runner exits 0. The typed-error runner exits 1 because
its repro assertions fail. Full raw logs are generated under `.temp/`.

These findings supersede the earlier recommendation to post a compiler
failure based on the private nightly import. They do not isolate whether
the different nightly behavior comes from the SDK version or runtime changes.
