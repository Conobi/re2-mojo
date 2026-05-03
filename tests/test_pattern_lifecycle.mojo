# Pattern lifecycle: compile a trivial regex, drop it, verify no crash.
# Movable-only contract is enforced statically by the trait combo
# (Pattern is Movable, NOT Copyable). We can't write a passing test that
# proves implicit-copy fails — that's a compile-error situation.

from re2_mojo.pattern import Pattern
from re2_mojo._ffi import open_lib

def test_compile_and_drop() raises:
    var lib = open_lib()
    var p = Pattern(lib^, String("hello"))
    print("compile OK")

def test_compile_with_metachars() raises:
    var lib = open_lib()
    var p = Pattern(lib^, String("^[a-z]+$"))
    print("metachar pattern OK")

def main() raises:
    test_compile_and_drop()
    test_compile_with_metachars()
    print("PASS: test_pattern_lifecycle")
