from re2_mojo import compile

def test_matches_all_basic() raises:
    var p = compile(String("\\d+"))
    var ms = p.matches_all(String("a 1 b 22 c 333"))
    if len(ms) != 3:
        raise Error("expected 3 matches, got " + String(len(ms)))
    if ms[0].group(0) != String("1"):
        raise Error("ms[0] wrong: " + ms[0].group(0))
    if ms[1].group(0) != String("22"):
        raise Error("ms[1] wrong: " + ms[1].group(0))
    if ms[2].group(0) != String("333"):
        raise Error("ms[2] wrong: " + ms[2].group(0))
    print("matches_all basic OK")

def test_matches_all_empty_input() raises:
    var p = compile(String("\\d+"))
    var ms = p.matches_all(String(""))
    if len(ms) != 0:
        raise Error("expected 0 matches")
    print("matches_all empty input OK")

def test_matches_all_no_matches() raises:
    var p = compile(String("\\d+"))
    var ms = p.matches_all(String("abc def"))
    if len(ms) != 0:
        raise Error("expected 0 matches")
    print("matches_all no-matches OK")

def test_matches_all_zero_width_advance() raises:
    # Pattern that can match zero-width at every position. MUST terminate.
    # Exact count is implementation-defined (advance-by-1 yields a finite, bounded result).
    var p = compile(String("a*"))
    var ms = p.matches_all(String("aaa"))
    if len(ms) == 0:
        raise Error("expected at least one match")
    print("matches_all zero-width terminated; count =", len(ms))

def main() raises:
    test_matches_all_basic()
    test_matches_all_empty_input()
    test_matches_all_no_matches()
    test_matches_all_zero_width_advance()
    print("PASS: test_pattern_matches_all")
