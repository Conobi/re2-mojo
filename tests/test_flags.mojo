from re2_mojo import compile
from re2_mojo.flags import CompileFlags

def test_multiline_off_anchors_at_string_boundary() raises:
    # multiline=False (default) → ^ matches only at start of input.
    var p = compile(String("^foo"))
    var m1 = p.search(String("foo\nbar"))
    if not m1:
        raise Error("expected match at line 1")
    var m2 = p.search(String("bar\nfoo"))
    if m2:
        raise Error("multiline=False; ^ should NOT match at line 2 start")
    print("multiline=False OK")

def test_multiline_on_anchors_at_line_boundary() raises:
    var f = CompileFlags(multiline=True)
    var p = compile(String("^foo"), f)
    var m = p.search(String("bar\nfoo"))
    if not m:
        raise Error("multiline=True; ^ should match at line 2 start")
    print("multiline=True OK")

def test_case_insensitive() raises:
    var f = CompileFlags(case_insensitive=True)
    var p = compile(String("foo"), f)
    var m = p.match(String("FOO"))
    if not m:
        raise Error("case_insensitive=True; should match FOO")
    print("case_insensitive OK")

def test_dot_matches_newline_off() raises:
    var p = compile(String("a.c"))
    var m = p.match(String("a\nc"))
    if m:
        raise Error("dot_matches_newline=False; . should NOT match \\n")
    print("dot_matches_newline=False OK")

def test_dot_matches_newline_on() raises:
    var f = CompileFlags(dot_matches_newline=True)
    var p = compile(String("a.c"), f)
    var m = p.match(String("a\nc"))
    if not m:
        raise Error("dot_matches_newline=True; . SHOULD match \\n")
    print("dot_matches_newline=True OK")

def main() raises:
    test_multiline_off_anchors_at_string_boundary()
    test_multiline_on_anchors_at_line_boundary()
    test_case_insensitive()
    test_dot_matches_newline_off()
    test_dot_matches_newline_on()
    print("PASS: test_flags")
