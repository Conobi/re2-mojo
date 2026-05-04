from re2_mojo import compile

def test_sub_count_one() raises:
    var p = compile(String("foo"))
    var out = p.sub(String("BAR"), String("foo foo foo"), 1)
    if out != String("BAR foo foo"):
        raise Error("got: " + out)
    print("sub count=1 OK")

def test_sub_count_zero_means_all() raises:
    var p = compile(String("foo"))
    var out = p.sub(String("BAR"), String("foo foo foo"), 0)
    if out != String("BAR BAR BAR"):
        raise Error("got: " + out)
    print("sub count=0 (all) OK")

def test_sub_with_capture_replacement() raises:
    var p = compile(String("(\\w+)@(\\w+)"))
    # cre2-native rewrite syntax: \1, \2
    var out = p.sub(String("\\2 at \\1"), String("alice@example"), 0)
    if out != String("example at alice"):
        raise Error("got: " + out)
    print("sub with rewrite refs OK")

def main() raises:
    test_sub_count_one()
    test_sub_count_zero_means_all()
    test_sub_with_capture_replacement()
    print("PASS: test_pattern_sub")
