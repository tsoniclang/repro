# What to file

Report the two repros using the corrected results and prepared text below.

| Repro | Recommended action | Text to copy |
| --- | --- | --- |
| Custom error accepted by `create_raising_task`, with a truncated message | Open one new **Mojo bug report** in `modular/modular` | [Issue title and form fields](repos/mojo-async-typed-error-payload-loss/ISSUE.md) |
| Compiler failure for a nested String-returning task | Add the minimal repro as a comment on the open async compiler report **#6842** | [Complete comment](repos/mojo-compiler-crash-nested-string-await-o0/UPSTREAM_COMMENT.md) |

## 1. New issue: unsupported typed async error

Open the [Mojo bug-report form](https://github.com/modular/modular/issues/new?template=mojo_bug_report.yaml).
If the direct form link does not load, use [New issue](https://github.com/modular/modular/issues/new/choose)
and choose **Mojo bug report**.

Use this title:

```text
[BUG] create_raising_task accepts a custom-error coroutine and loses part of its message
```

Open [ISSUE.md](repos/mojo-async-typed-error-payload-loss/ISSUE.md). Copy the text
under **Bug description**, **Steps to reproduce**, and **System information**
into the matching form fields. The first line supplies the title; do not copy
that line into a form field. The snippet and synchronous control are included,
so the issue can be reproduced without access to this checkout.

This is a report about accepting an unsupported error combination without a
diagnostic. The private task implementation uses native `Error`; the report
does not assume arbitrary typed async errors are supported.

## 2. Existing issue: async compiler failures

Open [modular/modular#6842](https://github.com/modular/modular/issues/6842), scroll
to the comment box, and paste the entire contents of
[UPSTREAM_COMMENT.md](repos/mojo-compiler-crash-nested-string-await-o0/UPSTREAM_COMMENT.md).

That open report already covers async compiler crashes and malformed
`pop.store` IR. Our no-capture, nested-return example is useful additional
evidence, but a shared root cause has not been established. Starting with a
comment lets maintainers decide whether to split it into a separate issue.
If they ask for a separate issue, use the comment as its body and this title:

```text
[BUG] Nested String-returning async task fails compilation at O0–O2
```

## Evidence and limits

- Both nightly SDKs reproduce the typed-error message loss at O0–O3.
- Both fail compilation of the nested String task at O0–O2 and run it at O3.
- The locked Conda O0 build reports heap corruption and a crash dump, then
  times out (exit 124). The wheel O0 build returns invalid-IR diagnostics (exit 1).
  The earlier exact SIGSEGV/exit-139 claim was not reconfirmed and has been
  removed from the current result tables.
- All 24 synchronous controls passed across the three SDK environments.
- Stable Mojo 1.0.0 lacks `_asyncrt`, so these are nightly reports.

The guarded runners save raw logs under `.temp/`, which is ignored by Git.
To share a full log, attach it to the upstream issue or comment. Both prepared
texts include the relevant diagnostics and reproduction code directly.
