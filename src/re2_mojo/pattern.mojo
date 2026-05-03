# Pattern — single-owner regex handle. Movable, NOT Copyable.
# Wraps cre2_regexp_t* via UnsafePointer[NoneType, MutAnyOrigin].
# __del__(deinit self) calls cre2_delete.
#
# Cannot be stored in stdlib List (which requires Copyable). For collections,
# use compile_shared() (Task 14) to get a SharedPattern instead.

from std.collections import List, Optional
from std.ffi import external_call
from std.memory import UnsafePointer
from re2_mojo._ffi import (
    _Cre2Lib,
    CreOptionsPtr,
    CreRegexpPtr,
    CRE2_UTF8,
    CRE2_UNANCHORED,
    CRE2_ANCHOR_START,
    CRE2_ANCHOR_BOTH,
)
from re2_mojo.errors import compile_error, match_error
from re2_mojo.flags import CompileFlags
from re2_mojo.match_result import Match


def _build_options(lib: _Cre2Lib, flags: CompileFlags) raises -> CreOptionsPtr:
    """Construct a cre2_options_t* with our defaults + caller's flags applied.
    Caller is responsible for cre2_opt_delete after use."""
    var opt = lib.lib.call["cre2_opt_new", CreOptionsPtr]()
    if not opt:
        raise compile_error("cre2_opt_new returned null")
    # Defaults: UTF-8 always; suppress RE2's stderr logging on bad patterns;
    # invert one_line so our `multiline=False` matches Python's default.
    lib.lib.call["cre2_opt_set_encoding", NoneType](opt, CRE2_UTF8)
    lib.lib.call["cre2_opt_set_log_errors", NoneType](opt, Int32(0))
    var one_line: Int32 = Int32(0) if flags.multiline else Int32(1)
    lib.lib.call["cre2_opt_set_one_line", NoneType](opt, one_line)
    var case_sens: Int32 = Int32(0) if flags.case_insensitive else Int32(1)
    lib.lib.call["cre2_opt_set_case_sensitive", NoneType](opt, case_sens)
    var dot_nl: Int32 = Int32(1) if flags.dot_matches_newline else Int32(0)
    lib.lib.call["cre2_opt_set_dot_nl", NoneType](opt, dot_nl)
    return opt


struct Pattern(Movable):
    """Single-owner compiled regex. Movable; not Copyable. Use compile_shared()
    if you need to store many patterns in a List or share across owners."""

    var _lib: _Cre2Lib
    var _re: CreRegexpPtr

    def __init__(
        out self,
        var lib: _Cre2Lib,
        pattern: String,
        flags: CompileFlags = CompileFlags(),
    ) raises:
        var opt = _build_options(lib, flags)
        var re = lib.lib.call["cre2_new", CreRegexpPtr](
            pattern.unsafe_ptr(), pattern.byte_length(), opt
        )
        # Always delete options regardless of compile success/failure.
        lib.lib.call["cre2_opt_delete", NoneType](opt)
        if not re:
            raise compile_error("cre2_new returned null for pattern: " + pattern)
        var err_code = lib.lib.call["cre2_error_code", Int32](re)
        if Int(err_code) != 0:
            var err_ptr = lib.lib.call[
                "cre2_error_string", UnsafePointer[UInt8, MutAnyOrigin]
            ](re)
            var err_msg = String(unsafe_from_utf8_ptr=err_ptr) if err_ptr else String("(no error message)")
            lib.lib.call["cre2_delete", NoneType](re)
            raise compile_error("invalid pattern '" + pattern + "': " + err_msg)
        self._lib = lib^
        self._re = re

    def __del__(deinit self):
        # cre2_delete is safe on a non-null pointer; we never construct
        # Pattern with self._re == null (constructor raises instead).
        self._lib.lib.call["cre2_delete", NoneType](self._re)

    def match(self, text: String, pos: Int = 0) raises -> Optional[Match]:
        """Anchored match at `pos`. Returns Some(Match) on success, None on no-match."""
        return self._do_match(text, pos, CRE2_ANCHOR_START)

    def search(self, text: String, pos: Int = 0) raises -> Optional[Match]:
        """Find first match at or after `pos`. No anchoring."""
        return self._do_match(text, pos, CRE2_UNANCHORED)

    def fullmatch(self, text: String) raises -> Optional[Match]:
        """Entire string must match (start-anchored AND must consume to end)."""
        return self._do_match(text, 0, CRE2_ANCHOR_BOTH)

    def matches_all(self, text: String) raises -> List[Match]:
        """All non-overlapping matches. Empty list if none.
        Zero-width matches advance pos by 1 byte to avoid infinite loops
        (matches Python re.finditer semantics)."""
        var results = List[Match]()
        var pos = 0
        var text_len = text.byte_length()
        while pos <= text_len:
            var m_opt = self.search(text, pos)
            if not m_opt:
                break
            var m = m_opt.value().copy()
            var end = m.end(0)
            results.append(m^)
            if end == pos:
                # Zero-width match — advance by 1 to make progress.
                pos = pos + 1
            else:
                pos = end
        return results^

    def _do_match(
        self, text: String, pos: Int, anchor: Int32
    ) raises -> Optional[Match]:
        # nmatch slots: 1 for group 0 (full match) + N for capturing groups.
        var ncaps = self._lib.lib.call["cre2_num_capturing_groups", Int32](self._re)
        var nmatch = Int(ncaps) + 1
        # Each cre2_string_t slot is 16 bytes on x86-64 (8-byte ptr + 4-byte int + 4 padding).
        var slot_bytes = 16
        var buf_size = slot_bytes * nmatch
        var buf = external_call[
            "malloc", UnsafePointer[UInt8, MutAnyOrigin]
        ](buf_size)
        if not buf:
            raise match_error("malloc failed for match buffer")

        var text_len = text.byte_length()
        var endpos = text_len  # whole-string scan after pos
        var ok = self._lib.lib.call["cre2_match", Int32](
            self._re,
            text.unsafe_ptr(),
            text_len,
            pos,
            endpos,
            anchor,
            buf,  # cre2_string_t* match[]
            Int32(nmatch),
        )
        if Int(ok) == 0:
            external_call["free", NoneType](buf)
            var none_result: Optional[Match] = None
            return none_result^

        # Each cre2_string_t slot is { data: char*, length: int }.
        # Read each slot, compute start/end relative to text base, eagerly copy
        # captured bytes into an owned String. Mojo statically proves the loop
        # body cannot raise (List/UnsafePointer/String ops here are infallible
        # in 0.26.x), so no try/except — buf is freed unconditionally below.
        var text_base = Int(text.unsafe_ptr())
        var captures = List[String]()
        var spans = List[Tuple[Int, Int]]()
        for i in range(nmatch):
            var slot = buf + (i * slot_bytes)
            var data_ptr_addr = slot.bitcast[UInt64]()[0]
            var length = (slot + 8).bitcast[Int32]()[0]
            if Int(data_ptr_addr) == 0:
                # Group did not participate — empty string + (-1, -1) span.
                captures.append(String(""))
                spans.append((-1, -1))
            else:
                var start = Int(data_ptr_addr) - text_base
                var end = start + Int(length)
                # Eagerly copy [start, end) into an owned List[UInt8] -> String.
                var slice_ptr = UnsafePointer[UInt8, MutAnyOrigin](
                    unsafe_from_address=Int(data_ptr_addr)
                )
                var bytes = List[UInt8]()
                for j in range(Int(length)):
                    bytes.append(slice_ptr[j])
                var captured = String(unsafe_from_utf8=bytes)
                captures.append(captured^)
                spans.append((start, end))

        external_call["free", NoneType](buf)
        return Match(captures^, spans^)
