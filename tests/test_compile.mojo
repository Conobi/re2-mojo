# compile() returns a Pattern; CompileFlags pass through correctly.

from re2_mojo import compile
from re2_mojo.flags import CompileFlags

def test_default_compile() raises:
    var p = compile(String("foo"))
    print("default compile OK")

def test_compile_with_flags() raises:
    var f = CompileFlags(multiline=True)
    var p = compile(String("^foo$"), f)
    print("flagged compile OK")

def main() raises:
    test_default_compile()
    test_compile_with_flags()
    print("PASS: test_compile")
