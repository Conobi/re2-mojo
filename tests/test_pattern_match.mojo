# Pattern.match: anchored at pos. Returns Optional[Match]. None on no-match.
# Match is self-owning: input string can be freed after match() returns.

from re2_mojo import compile

def test_match_anchored_at_zero() raises:
    var p = compile(String("foo"))
    var m = p.match(String("foobar"))
    if not m:
        raise Error("expected match")
    var mm = m.value().copy()
    if mm.group(0) != String("foo"):
        raise Error("group(0) mismatch: got " + mm.group(0))
    print("anchored at 0 OK")

def test_match_no_match_at_zero() raises:
    var p = compile(String("foo"))
    var m = p.match(String("xfoobar"))
    if m:
        raise Error("expected no-match (foo isn't at pos 0)")
    print("no-match at 0 OK")

def test_match_anchored_at_pos() raises:
    var p = compile(String("foo"))
    var m = p.match(String("xfoobar"), 1)
    if not m:
        raise Error("expected match at pos=1")
    if m.value().group(0) != String("foo"):
        raise Error("group(0) mismatch")
    print("anchored at pos OK")

def test_match_with_capture() raises:
    var p = compile(String("(\\d+)-(\\w+)"))
    var m = p.match(String("42-hello world"))
    if not m:
        raise Error("expected match")
    var mm = m.value().copy()
    if mm.group(0) != String("42-hello"):
        raise Error("group(0) wrong: " + mm.group(0))
    if mm.group(1) != String("42"):
        raise Error("group(1) wrong: " + mm.group(1))
    if mm.group(2) != String("hello"):
        raise Error("group(2) wrong: " + mm.group(2))
    print("captures OK")

def main() raises:
    test_match_anchored_at_zero()
    test_match_no_match_at_zero()
    test_match_anchored_at_pos()
    test_match_with_capture()
    print("PASS: test_pattern_match")
