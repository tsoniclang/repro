# Withdrawn: do not post the previous compiler-failure comment

The previous comment described a repro that imported the private nightly
module `std.runtime._asyncrt`.

The current example uses Mojo 1.0.0's documented public
`std.runtime.asyncrt` interface. With both the 1.0.0 wheel and Conda SDKs, the
example and synchronous control build and run at O0–O3. The example prints `hello`.

There is currently no compiler failure reproduced through the public interface
in this directory. Do not use the previous comment as evidence on
[modular/modular#6842](https://github.com/modular/modular/issues/6842).

See [the current results](README.md) and [filing status](../../FILING.md).
