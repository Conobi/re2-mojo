# Match — self-owning capture container.
# At construction (inside Pattern.match/search/etc), each capture group's
# bytes are EAGERLY COPIED from the input into a fresh String stored here.
# Once the matching call returns, the input string can be freed.
#
# Internally:
#   _captures: List[String]            — captured bytes; index 0 = full match, 1+ = groups
#   _spans:    List[Tuple[Int, Int]]   — (start_byte, end_byte) into the original input
#                                        recorded at match time; valid integers forever.

from std.collections import List


struct Match(Copyable, Movable):
    var _captures: List[String]
    var _spans: List[Tuple[Int, Int]]

    def __init__(out self, var captures: List[String], var spans: List[Tuple[Int, Int]]):
        self._captures = captures^
        self._spans = spans^

    def group(self, n: Int = 0) raises -> String:
        if n < 0 or n >= len(self._captures):
            raise Error(
                "Match.group: index "
                + String(n)
                + " out of range (have "
                + String(len(self._captures))
                + ")"
            )
        return self._captures[n]

    def start(self, n: Int = 0) raises -> Int:
        if n < 0 or n >= len(self._spans):
            raise Error("Match.start: index out of range")
        return self._spans[n][0]

    def end(self, n: Int = 0) raises -> Int:
        if n < 0 or n >= len(self._spans):
            raise Error("Match.end: index out of range")
        return self._spans[n][1]

    def span(self, n: Int = 0) raises -> Tuple[Int, Int]:
        if n < 0 or n >= len(self._spans):
            raise Error("Match.span: index out of range")
        return self._spans[n]

    def captures_count(self) -> Int:
        # Number of capture groups (excluding group 0 = full match).
        return len(self._captures) - 1
