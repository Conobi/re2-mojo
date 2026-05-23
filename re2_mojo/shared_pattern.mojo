# SharedPattern - Copyable, Movable refcounted regex handle.
#
# Layout: two heap allocations.
#   - rc:    UnsafePointer[Int64]   (atomic refcount, accessed via bitcast to
#                                    Atomic[DType.int64] since Atomic itself
#                                    is non-Movable and cannot live in a
#                                    Movable struct alongside Pattern).
#   - inner: UnsafePointer[Pattern] (the wrapped Pattern instance).
#
# .copy() bumps the refcount and returns a sibling SharedPattern pointing
# at the same control allocation. __del__ decrements; when it transitions
# from 1 to 0, the inner Pattern is destroyed (which calls re2m_delete via
# Pattern's __del__) and both allocations are freed.
#
# Atomic[DType.int64] is NOT Movable, so we can't put it directly inside
# a Movable struct. Workaround: alloc Int64, write 1, then for each
# refcount op bitcast the pointer to Atomic[DType.int64]*.
#
# Direct field access on a SharedPattern from outside (e.g. `sp.inner[0]...`)
# is unsafe under Mojo's ASAP-destruction; all interaction MUST go through
# methods so `self` keeps the handle alive for the duration of the call.

from std.collections import List, Optional
from std.memory import UnsafePointer, alloc
from std.atomic.atomic import Atomic
from re2_mojo.pattern import Pattern
from re2_mojo.flags import CompileFlags
from re2_mojo.match_result import Match


struct SharedPattern(Copyable, Movable):
    """Refcounted, Copyable+Movable handle to a compiled Pattern. Use this
    when storing many patterns in a List or sharing across owners. Inherits
    all multiline/case_insensitive/dot_matches_newline handling from the
    underlying compile() factory."""

    var _rc: UnsafePointer[Int64, MutExternalOrigin]
    var _inner: UnsafePointer[Pattern, MutExternalOrigin]

    def __init__(out self, var inner: Pattern):
        # Allocate the refcount slot and initialize to 1.
        var rcp = alloc[Int64](1)
        rcp[0] = 1
        # Allocate the Pattern slot and move the caller's Pattern into it.
        var ip = alloc[Pattern](1)
        ip.init_pointee_move(inner^)
        self._rc = rcp
        self._inner = ip

    def __init__(
        out self,
        rc: UnsafePointer[Int64, MutExternalOrigin],
        inner: UnsafePointer[Pattern, MutExternalOrigin],
    ):
        """Internal alt constructor used by .copy() to build a sibling
        SharedPattern that shares the same control allocations. Does NOT
        bump the refcount; the caller (.copy()) bumps before invoking."""
        self._rc = rc
        self._inner = inner

    def copy(self) -> Self:
        # Bump refcount atomically, then construct a sibling pointing at
        # the same control allocations.
        var atomic_ptr = self._rc.bitcast[Atomic[DType.int64]]()
        _ = atomic_ptr[0].fetch_add(1)
        return Self(self._rc, self._inner)

    def __del__(deinit self):
        var atomic_ptr = self._rc.bitcast[Atomic[DType.int64]]()
        var prev = atomic_ptr[0].fetch_sub(1)
        if prev == 1:
            # Last reference - destroy the inner Pattern (calls re2m_delete
            # via Pattern.__del__) and free both control allocations.
            self._inner.destroy_pointee()
            self._inner.free()
            self._rc.free()

    # --- Forwarded Pattern methods. ---
    # All access to _inner is via self.<method>, so self stays live for the
    # call duration. Direct `sp._inner[0]` access from outside is unsafe.

    def match(self, text: String, pos: Int = 0) raises -> Optional[Match]:
        return self._inner[0].match(text, pos)

    def search(self, text: String, pos: Int = 0) raises -> Optional[Match]:
        return self._inner[0].search(text, pos)

    def fullmatch(self, text: String) raises -> Optional[Match]:
        return self._inner[0].fullmatch(text)

    def matches_all(self, text: String) raises -> List[Match]:
        return self._inner[0].matches_all(text)

    def sub(self, repl: String, text: String, count: Int = 0) raises -> String:
        return self._inner[0].sub(repl, text, count)

    def captures_count(self) -> Int:
        return self._inner[0].captures_count()
