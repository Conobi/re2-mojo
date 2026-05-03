# Error helpers. Mojo Error is a single type; we use prefixed message strings
# (mirrors dixi-parse's `MissingPragmaError:` convention) so callers can
# pattern-match if they need to distinguish.

def compile_error(msg: String) -> Error:
    return Error(String("CompileError: ") + msg)

def match_error(msg: String) -> Error:
    return Error(String("MatchError: ") + msg)
