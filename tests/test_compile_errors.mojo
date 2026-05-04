# CompileError surfaces for: malformed regex, RE2-rejected features
# (backref, lookaround). Pattern's __init__ should raise with a useful message.

from re2_mojo import compile

def _expect_compile_error(pat: String, hint: String) raises:
    try:
        var p = compile(pat)
        raise Error("expected CompileError for pattern: " + pat + " (" + hint + ")")
    except e:
        var msg = String(e)
        # Both "CompileError:" prefix and the original pattern should be in the message.
        if msg.find(String("CompileError:")) < 0:
            raise Error("error not prefixed CompileError; got: " + msg)
        print("OK rejected:", hint)

def test_unbalanced_paren() raises:
    _expect_compile_error(String("foo("), String("unbalanced ("))

def test_invalid_quantifier() raises:
    _expect_compile_error(String("*foo"), String("leading *"))

def test_backreference_rejected() raises:
    # RE2 rejects backrefs (not regular). Pattern compile must fail.
    _expect_compile_error(String("(\\w+)\\s+\\1"), String("backreference \\1"))

def test_lookahead_rejected() raises:
    _expect_compile_error(String("foo(?=bar)"), String("lookahead (?=)"))

def test_lookbehind_rejected() raises:
    _expect_compile_error(String("(?<=foo)bar"), String("lookbehind (?<=)"))

def main() raises:
    test_unbalanced_paren()
    test_invalid_quantifier()
    test_backreference_rejected()
    test_lookahead_rejected()
    test_lookbehind_rejected()
    print("PASS: test_compile_errors")
