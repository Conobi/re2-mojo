# re2-mojo

Mojo bindings for [Google RE2](https://github.com/google/re2) — a fast,
linear-time regular expression engine — via an in-tree C++ shim
(`cpp/libre2-mojo/`) that statically links vendored RE2 + abseil-cpp.

## Status

V0 — single-process, single-threaded, UTF-8 input, no streaming. See
`docs/project-context.md` for current scope.

## Install

Build the shim once per machine:

```sh
bash scripts/install.sh
```

The script installs minimal pacman deps (`cmake git pkgconf base-devel`) and
runs `scripts/build.sh`, which configures CMake, fetches vendored RE2
(`2024-07-02`) + abseil-cpp (`20240722.0`) via `FetchContent` at pinned
tags, compiles, and drops `lib/libre2_mojo.so`. Cost: ~30 s first run, ~3 s
incremental. Idempotent — safe to rerun.

If pacman deps are already satisfied, you can skip the wrapper and call
`bash scripts/build.sh` directly.

The Mojo binding loads the shim via an **absolute path** baked into
`_ffi.mojo` — Mojo MCP's `execute` does NOT propagate `LD_LIBRARY_PATH`,
so system-style short-name resolution is not used. Consumers that embed
re2-mojo as a sibling project pass the absolute path to
`OwnedDLHandle("/abs/path/to/lib/libre2_mojo.so")`.

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

## API

- `compile(pattern: String, flags: CompileFlags = CompileFlags()) raises -> Pattern`
- `compile_shared(pattern: String, flags: CompileFlags = CompileFlags()) raises -> SharedPattern`
- `Pattern(Movable)` methods: `match`, `search`, `fullmatch`, `matches_all`, `sub`, `captures_count`
- `SharedPattern(Copyable, Movable)` — same methods plus `.copy()` to share
- `Match(Copyable, Movable)` — `group(n)`, `start(n)`, `end(n)`, `span(n)`, `captures_count()`. Self-owning: each capture's bytes are eagerly copied at construction; the input string need not outlive the Match.
- `CompileFlags(Copyable, Movable)` — fields `multiline`, `case_insensitive`, `dot_matches_newline`

## Semantic limits

RE2 is strictly regular and rejects features that exit regular languages.
Patterns using any of these raise `CompileError` at `compile()` time:

- Backreferences: `\1`, `\g<name>`
- Lookahead / lookbehind: `(?=…)`, `(?!…)`, `(?<=…)`, `(?<!…)`
- Conditional groups: `(?(1)…|…)`
- Atomic groups, possessive quantifiers, recursive patterns

Replacement (`sub`) uses RE2-native `\1`-style backreferences — NOT Python's
`\g<1>` form.

V0 input is **UTF-8 only**. Latin-1 / raw-bytes modes are deferred.

## Concurrency

`Pattern` and `SharedPattern` are not yet documented as thread-safe in V0.
RE2 itself is logically immutable and supports concurrent matches; we'll
add explicit thread-safety guarantees once Mojo's concurrency model is
formalized. SharedPattern's refcount uses atomic primitives so it's ready
for a future concurrency story.

## License

MIT (this binding). RE2 and abseil-cpp are vendored at build time and
remain under their upstream licenses (BSD-3-Clause and Apache-2.0
respectively); see `LICENSE` for full attribution.
