from re2_mojo import compile

def test_search_finds_anywhere() raises:
    var p = compile(String("foo"))
    var m = p.search(String("xyzfoobar"))
    if not m:
        raise Error("expected search to find 'foo'")
    var mm = m.value().copy()
    if mm.group(0) != String("foo"):
        raise Error("group(0) wrong")
    if mm.start(0) != 3:
        raise Error("start should be 3, got " + String(mm.start(0)))
    if mm.end(0) != 6:
        raise Error("end should be 6")
    print("search basic OK")

def test_search_with_pos() raises:
    var p = compile(String("foo"))
    # First foo at 0, second at 8.
    var m = p.search(String("foo bar foo"), 1)
    if not m:
        raise Error("expected match at >= 1")
    if m.value().start(0) != 8:
        raise Error("expected second foo at 8")
    print("search with pos OK")

def test_fullmatch_succeeds() raises:
    var p = compile(String("\\d+"))
    var m = p.fullmatch(String("12345"))
    if not m:
        raise Error("expected fullmatch")
    if m.value().group(0) != String("12345"):
        raise Error("group(0) wrong")
    print("fullmatch OK")

def test_fullmatch_rejects_partial() raises:
    var p = compile(String("\\d+"))
    var m = p.fullmatch(String("12345abc"))
    if m:
        raise Error("expected fullmatch to fail (input has trailing chars)")
    print("fullmatch reject OK")

def main() raises:
    test_search_finds_anywhere()
    test_search_with_pos()
    test_fullmatch_succeeds()
    test_fullmatch_rejects_partial()
    print("PASS: test_pattern_search")
