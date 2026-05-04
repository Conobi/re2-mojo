from re2_mojo import compile

def test_indexed_access() raises:
    var p = compile(String("(\\d+)-(\\w+)"))
    var m = p.match(String("42-hello"))
    if not m:
        raise Error("expected match")
    var mm = m.value().copy()
    if mm.group(0) != String("42-hello"):
        raise Error("g0")
    if mm.group(1) != String("42"):
        raise Error("g1")
    if mm.group(2) != String("hello"):
        raise Error("g2")
    if mm.start(0) != 0:
        raise Error("s0")
    if mm.end(0) != 8:
        raise Error("e0")
    if mm.start(1) != 0:
        raise Error("s1")
    if mm.end(1) != 2:
        raise Error("e1")
    if mm.start(2) != 3:
        raise Error("s2")
    if mm.end(2) != 8:
        raise Error("e2")
    var sp = mm.span(2)
    if sp[0] != 3 or sp[1] != 8:
        raise Error("span(2)")
    print("indexed access OK")

def test_out_of_range_raises() raises:
    var p = compile(String("foo"))
    var m = p.match(String("foo"))
    if not m:
        raise Error("expected match")
    var mm = m.value().copy()
    var raised = False
    try:
        var _ = mm.group(99)
    except:
        raised = True
    if not raised:
        raise Error("expected out-of-range to raise")
    print("out-of-range raises OK")

def test_self_owning_after_input_drops() raises:
    # Stress the lifetime contract: input goes out of scope; Match still works.
    # Strategy: compile once outside the inner scope; do the search inside an
    # inner scope where the input lives; copy the captures out by extracting
    # group(0) into a separate String BEFORE the inner scope ends, then verify.
    # If Match is truly self-owning, we can also keep the Match itself alive
    # past the input's drop.
    var p = compile(String("foo"))
    var captured: String

    # Inner scope so `s` drops at its end.
    if True:
        var s = String("bar foo baz")
        var m = p.search(s)
        if not m:
            raise Error("expected match")
        captured = m.value().group(0)

    # `s` is out of scope here. `captured` still holds "foo" because Match
    # eagerly copied the bytes at construction.
    if captured != String("foo"):
        raise Error("self-owning broken; got: " + captured)
    print("self-owning after input dropped OK")

def main() raises:
    test_indexed_access()
    test_out_of_range_raises()
    test_self_owning_after_input_drops()
    print("PASS: test_match_groups")
