# Public factory functions: compile() returns Pattern; compile_shared()
# returns SharedPattern (refcounted handle, Copyable+Movable).

from re2_mojo._ffi import open_lib
from re2_mojo.flags import CompileFlags
from re2_mojo.pattern import Pattern
from re2_mojo.shared_pattern import SharedPattern


def compile(pattern: String, flags: CompileFlags = CompileFlags()) raises -> Pattern:
    """Compile `pattern` into a single-owner Pattern. For collection storage
    or multi-owner use, see compile_shared()."""
    var lib = open_lib()
    return Pattern(lib^, pattern, flags)


def compile_shared(
    pattern: String, flags: CompileFlags = CompileFlags()
) raises -> SharedPattern:
    """Compile `pattern` into a refcounted SharedPattern. Use this when
    storing many patterns in a List or sharing across owners. Inherits all
    multiline / case_insensitive / dot_matches_newline / inline-flag handling
    from compile()."""
    var p = compile(pattern, flags)
    return SharedPattern(p^)
