# Public factory functions: compile() returns Pattern; compile_shared()
# returns SharedPattern (added in a later task).

from re2_mojo._ffi import open_lib
from re2_mojo.flags import CompileFlags
from re2_mojo.pattern import Pattern


def compile(pattern: String, flags: CompileFlags = CompileFlags()) raises -> Pattern:
    """Compile `pattern` into a single-owner Pattern. For collection storage
    or multi-owner use, see compile_shared() (Task 14)."""
    var lib = open_lib()
    return Pattern(lib^, pattern, flags)
