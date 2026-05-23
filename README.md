# re2-mojo

Mojo bindings for [Google RE2](https://github.com/google/re2) — a fast,
linear-time regular expression engine — via an in-tree C++ shim
(`cpp/libre2-mojo/`) that statically links vendored RE2 + abseil-cpp.

> [!WARNING]
> **APIs unstable.** Single-process, single-threaded, UTF-8 input,
> no streaming.

## Install

re2-mojo is a Mojo library. Build it with [`mojox`](https://pypi.org/project/mojox/)
under [`uv`](https://docs.astral.sh/uv/):

```sh
git clone https://github.com/Conobi/re2-mojo.git
cd re2-mojo
uv sync   # pulls mojox + the Mojo compiler, runs scripts/build.sh as pre-build
```

`uv sync` invokes `mojox-build`, which runs `scripts/build.sh` to fetch
vendored RE2 (`2024-07-02`) + abseil-cpp (`20240722.0`) via CMake
`FetchContent` at pinned tags, compile, and drop `lib/libre2_mojo.so`.
Cost: ~30 s first run, ~3 s incremental. Requires `cmake`, `git`,
`pkgconf`, and a C++ toolchain on `PATH`.

If you only want the shim (no `uv`), run `bash scripts/install.sh`
(adds the pacman deps then calls `scripts/build.sh`).

At import time the shim is resolved by `_ffi.mojo`: bare soname first
(picks up RUNPATH from the mojox wheel, or `LD_LIBRARY_PATH` /
`ld.so.cache`), then CWD-relative `lib/libre2_mojo.so` as a fallback.

## Quickstart

```mojo
from re2_mojo import compile, compile_shared, CompileFlags, SharedPattern

def main() raises:
    # Single-owner Pattern (Movable, NOT Copyable).
    var p = compile(String("(\\d+)-(\\w+)"))
    var m = p.match(String("42-hello"))
    if m:
        var mm = m.value().copy()
        print(mm.group(0))  # "42-hello"
        print(mm.group(1))  # "42"
        print(mm.group(2))  # "hello"

    # SharedPattern for collection storage / multi-owner sharing.
    var sp = compile_shared(String("\\d+"))
    var rules = List[SharedPattern]()
    rules.append(sp.copy())
    rules.append(compile_shared(String("[a-z]+")))

    # Compile-time options.
    var flags = CompileFlags(multiline=True, case_insensitive=True)
    var p2 = compile(String("^FOO"), flags)
```

Runnable examples under `examples/` (`lexer_table_demo.mojo`,
`url_split_demo.mojo`).

## API

| Call | Returns | Notes |
|---|---|---|
| `compile(s, flags?)` | `Pattern` | Movable, NOT Copyable. |
| `compile_shared(s, flags?)` | `SharedPattern` | Copyable + Movable; use for collections. |
| `Pattern.match(s)` | `Optional[Match]` | Anchored at both ends. |
| `Pattern.search(s)` | `Optional[Match]` | Unanchored. |
| `Pattern.fullmatch(s)` | `Optional[Match]` | Anchored; must consume all input. |
| `Pattern.matches_all(s)` | `List[Match]` | All non-overlapping matches. |
| `Pattern.sub(s, repl)` | `String` | RE2-native `\1` backrefs — not Python's `\g<1>`. |
| `Pattern.captures_count()` | `Int` | |

`Match(Copyable, Movable)` — `group(n)`, `start(n)`, `end(n)`,
`span(n)`, `captures_count()`. Self-owning: capture bytes are eagerly
copied at construction, so the input string need not outlive the Match.

`CompileFlags(Copyable, Movable)` — `multiline`, `case_insensitive`,
`dot_matches_newline`.

## Semantic limits

RE2 is strictly regular and rejects features that exit regular
languages. Patterns using backreferences (`\1`, `\g<name>`), lookahead
or lookbehind (`(?=…)`, `(?<=…)`), conditional groups (`(?(1)…|…)`),
atomic groups, possessive quantifiers, or recursion raise
`CompileError` at `compile()` time. Input is UTF-8 only; Latin-1 and
raw-bytes modes are deferred.

## Concurrency

re2-mojo is not yet documented as thread-safe. RE2 itself is logically
immutable and supports concurrent matches; explicit guarantees will
land once Mojo's concurrency model is formalized. `SharedPattern`'s
refcount uses atomic primitives, so it's ready for a future
concurrency story.

## Project layout

```
re2_mojo/          Mojo bindings (public API + _ffi loader)
cpp/libre2-mojo/   C++ shim (vendors RE2 + abseil-cpp via FetchContent)
scripts/           install + build helpers
lib/               built `.so` (gitignored; .gitkeep tracked)
examples/          runnable demos
tests/             Mojo test suite
```

## License

MIT (this binding). RE2 and abseil-cpp are vendored at build time and
remain under their upstream licenses (BSD-3-Clause and Apache-2.0
respectively); see `LICENSE` for full attribution.
