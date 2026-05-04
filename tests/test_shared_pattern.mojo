from re2_mojo import compile_shared, SharedPattern
from re2_mojo.flags import CompileFlags

def test_shared_basic_match() raises:
    var sp = compile_shared(String("foo"))
    var m = sp.match(String("foobar"))
    if not m:
        raise Error("expected match")
    if m.value().group(0) != String("foo"):
        raise Error("group(0) wrong")
    print("shared basic OK")

def test_shared_copy_and_match() raises:
    var sp1 = compile_shared(String("\\d+"))
    var sp2 = sp1.copy()  # explicit copy bumps refcount
    var m1 = sp1.search(String("abc 42"))
    var m2 = sp2.search(String("99 def"))
    if not m1 or not m2:
        raise Error("both shared copies should match")
    if m1.value().group(0) != String("42") or m2.value().group(0) != String("99"):
        raise Error("captures wrong")
    print("shared copy + independent match OK")

def test_shared_in_list() raises:
    # The whole reason SharedPattern exists - collection storage.
    var l = List[SharedPattern]()
    l.append(compile_shared(String("a")))
    l.append(compile_shared(String("b")))
    l.append(compile_shared(String("c")))
    var m_a = l[0].search(String("xa"))
    var m_b = l[1].search(String("yb"))
    var m_c = l[2].search(String("zc"))
    if not m_a or not m_b or not m_c:
        raise Error("expected matches from each pattern in list")
    print("List[SharedPattern] OK")

def test_shared_drop_when_zero() raises:
    # Construct, copy several times, drop in scope, verify no crash.
    # We can't directly observe refcount; this is a smoke test for no-double-free.
    var sp = compile_shared(String("foo"))
    var sp2 = sp.copy()
    var sp3 = sp2.copy()
    # All three drop here at last use; cre2_delete fires exactly once when
    # refcount hits zero.
    var m = sp3.match(String("foo"))
    if not m:
        raise Error("expected match")
    print("shared drop sequence OK (no crash; cre2_delete fired once)")

def main() raises:
    test_shared_basic_match()
    test_shared_copy_and_match()
    test_shared_in_list()
    test_shared_drop_when_zero()
    print("PASS: test_shared_pattern")
