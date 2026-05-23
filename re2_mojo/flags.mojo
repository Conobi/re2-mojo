# Compile-time options for compile() / compile_shared(). Named-field struct
# (NOT bitflag constants like Python `re.MULTILINE | re.IGNORECASE`).
# All defaults are False — most users never construct one.
#
# Naming notes:
#   - `multiline` (positive Mojo convention) maps to cre2's INVERSE `one_line`.
#     We flip internally so multiline=True == Python's re.MULTILINE behavior:
#     ^/$ match line boundaries.
#   - `case_insensitive` maps to cre2's `case_sensitive` (negation, applied internally).
#   - `dot_matches_newline` maps directly to cre2's `dot_nl`.

struct CompileFlags(Copyable, Movable):
    var multiline: Bool
    var case_insensitive: Bool
    var dot_matches_newline: Bool

    def __init__(
        out self,
        multiline: Bool = False,
        case_insensitive: Bool = False,
        dot_matches_newline: Bool = False,
    ):
        self.multiline = multiline
        self.case_insensitive = case_insensitive
        self.dot_matches_newline = dot_matches_newline
