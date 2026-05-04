from re2_mojo import compile

def test_zero_captures() raises:
    var p = compile(String("foo"))
    if p.captures_count() != 0:
        raise Error("expected 0")
    print("zero captures OK")

def test_three_captures() raises:
    var p = compile(String("(a)(b)(c)"))
    if p.captures_count() != 3:
        raise Error("expected 3, got " + String(p.captures_count()))
    print("three captures OK")

def test_non_capturing_group_excluded() raises:
    var p = compile(String("(?:a)(b)"))
    if p.captures_count() != 1:
        raise Error("expected 1, got " + String(p.captures_count()))
    print("non-capturing group excluded OK")

def main() raises:
    test_zero_captures()
    test_three_captures()
    test_non_capturing_group_excluded()
    print("PASS: test_pattern_captures_count")
