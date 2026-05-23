# Pattern — single-owner regex handle. Movable, NOT Copyable.
# Wraps re2m_regexp_t* via UnsafePointer[NoneType, MutAnyOrigin].
# __del__(deinit self) calls re2m_delete.
#
# Cannot be stored in stdlib List (which requires Copyable). For collections,
# use compile_shared() to get a SharedPattern instead.

from std.collections import List, Optional
from std.memory import UnsafePointer, alloc
from re2_mojo._ffi import (
    _Re2mLib,
    Re2mOptionsPtr,
    Re2mRegexpPtr,
    RE2M_UTF8,
    RE2M_UNANCHORED,
    RE2M_ANCHOR_START,
    RE2M_ANCHOR_BOTH,
)
from re2_mojo.errors import compile_error, match_error
from re2_mojo.flags import CompileFlags
from re2_mojo.match_result import Match


def _expand_repl(repl: String, m: Match) raises -> String:
    """Expand re2m-style `\\N` backreferences in `repl` against captured groups.
    `\\0` = full match. `\\\\` -> literal backslash. Unrecognized `\\X` is left
    literal (both bytes preserved). Out-of-range `\\N` also left literal."""
    var out = String("")
    var i = 0
    var n = repl.byte_length()
    while i < n:
        var ch = String(repl[byte=i:i+1])
        if ch == String("\\") and i + 1 < n:
            var nxt = String(repl[byte=i+1:i+2])
            # Digit?
            if nxt >= String("0") and nxt <= String("9"):
                var nxt_byte = nxt.unsafe_ptr()[0]
                var idx = Int(nxt_byte) - 48  # ord('0') == 48
                if idx <= m.captures_count():
                    out = out + m.group(idx)
                else:
                    # Out-of-range: keep both bytes verbatim.
                    out = out + ch
                    out = out + nxt
                i = i + 2
                continue
            # Escaped backslash.
            if nxt == String("\\"):
                out = out + String("\\")
                i = i + 2
                continue
        out = out + ch
        i = i + 1
    return out^


def _build_options(lib: _Re2mLib, flags: CompileFlags) raises -> Re2mOptionsPtr:
    """Construct a re2m_options_t* with our defaults + caller's flags applied.
    Caller is responsible for re2m_opt_delete after use.

    Note: `multiline` is NOT applied here. RE2's `one_line` option is only
    consulted when `posix_syntax=true`; in our default Perl-style mode it's
    a no-op. Multi-line is instead enabled by prepending `(?m)` to the
    pattern itself (see `_with_inline_flags`)."""
    var opt_result = lib.lib.call["re2m_opt_new", Optional[Re2mOptionsPtr]]()
    if not opt_result:
        raise compile_error("re2m_opt_new returned null")
    var opt = opt_result.value()
    lib.lib.call["re2m_opt_set_encoding", NoneType](opt, RE2M_UTF8)
    lib.lib.call["re2m_opt_set_log_errors", NoneType](opt, Int32(0))
    var case_sens: Int32 = Int32(0) if flags.case_insensitive else Int32(1)
    lib.lib.call["re2m_opt_set_case_sensitive", NoneType](opt, case_sens)
    var dot_nl: Int32 = Int32(1) if flags.dot_matches_newline else Int32(0)
    lib.lib.call["re2m_opt_set_dot_nl", NoneType](opt, dot_nl)
    return opt


def _with_inline_flags(pattern: String, flags: CompileFlags) -> String:
    """Prepend RE2 inline flag groups for behaviors that re2m options do not
    cover in Perl-syntax mode. Currently only `multiline` (RE2's `one_line`
    option requires `posix_syntax=true`, which we don't enable, so we use
    the inline `(?m)` flag instead)."""
    if flags.multiline:
        return String("(?m)") + pattern
    return pattern


struct Pattern(Movable):
    """Single-owner compiled regex. Movable; not Copyable. Use compile_shared()
    if you need to store many patterns in a List or share across owners."""

    var _lib: _Re2mLib
    var _re: Re2mRegexpPtr

    def __init__(
        out self,
        var lib: _Re2mLib,
        pattern: String,
        flags: CompileFlags = CompileFlags(),
    ) raises:
        var opt = _build_options(lib, flags)
        var effective_pattern = _with_inline_flags(pattern, flags)
        var re_result = lib.lib.call["re2m_new", Optional[Re2mRegexpPtr]](
            effective_pattern.unsafe_ptr(),
            effective_pattern.byte_length(),
            opt,
        )
        lib.lib.call["re2m_opt_delete", NoneType](opt)
        if not re_result:
            raise compile_error("re2m_new returned null for pattern: " + pattern)
        var re = re_result.value()
        var err_code = lib.lib.call["re2m_error_code", Int32](re)
        if Int(err_code) != 0:
            var err_ptr = lib.lib.call[
                "re2m_error_string", Optional[UnsafePointer[UInt8, MutAnyOrigin]]
            ](re)
            var err_msg = String(unsafe_from_utf8_ptr=err_ptr.value()) if err_ptr else String("(no error message)")
            lib.lib.call["re2m_delete", NoneType](re)
            raise compile_error("invalid pattern '" + pattern + "': " + err_msg)
        self._lib = lib^
        self._re = re

    def __del__(deinit self):
        # re2m_delete is safe on a non-null pointer; we never construct
        # Pattern with self._re == null (constructor raises instead).
        self._lib.lib.call["re2m_delete", NoneType](self._re)

    def match(self, text: String, pos: Int = 0) raises -> Optional[Match]:
        """Anchored match at `pos`. Returns Some(Match) on success, None on no-match."""
        return self._do_match(text, pos, RE2M_ANCHOR_START)

    def search(self, text: String, pos: Int = 0) raises -> Optional[Match]:
        """Find first match at or after `pos`. No anchoring."""
        return self._do_match(text, pos, RE2M_UNANCHORED)

    def fullmatch(self, text: String) raises -> Optional[Match]:
        """Entire string must match (start-anchored AND must consume to end)."""
        return self._do_match(text, 0, RE2M_ANCHOR_BOTH)

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

    def sub(
        self, repl: String, text: String, count: Int = 0
    ) raises -> String:
        """Replace matches with `repl`. count=0 -> all; count=1 -> first only;
        count=N -> first N. Replacement syntax uses re2m-native `\\1`, `\\2`
        for backrefs (NOT Python's `\\g<1>` form). `\\0` = full match."""
        if count == 1:
            return self._sub_once(repl, text, 0)
        if count == 0:
            # Replace all (loop until no more matches).
            var current = text
            var pos = 0
            while True:
                var m_opt = self.search(current, pos)
                if not m_opt:
                    break
                var mm = m_opt.value().copy()
                var s = mm.start(0)
                var e = mm.end(0)
                var rewritten = _expand_repl(repl, mm)
                var prefix = String(current[byte=:s])
                var suffix = String(current[byte=e:])
                current = prefix + rewritten + suffix
                pos = s + rewritten.byte_length()
                if e == s:
                    pos = pos + 1  # zero-width advance
            return current^
        # count > 1: loop count times.
        var result = text
        var pos = 0
        for _ in range(count):
            var m_opt = self.search(result, pos)
            if not m_opt:
                break
            var mm = m_opt.value().copy()
            var s = mm.start(0)
            var e = mm.end(0)
            var rewritten = _expand_repl(repl, mm)
            var prefix = String(result[byte=:s])
            var suffix = String(result[byte=e:])
            result = prefix + rewritten + suffix
            pos = s + rewritten.byte_length()
            if e == s:
                pos = pos + 1
        return result^

    def _sub_once(
        self, repl: String, text: String, pos: Int
    ) raises -> String:
        var m_opt = self.search(text, pos)
        if not m_opt:
            return text
        var mm = m_opt.value().copy()
        var s = mm.start(0)
        var e = mm.end(0)
        var rewritten = _expand_repl(repl, mm)
        return String(text[byte=:s]) + rewritten + String(text[byte=e:])

    def captures_count(self) -> Int:
        """Number of capturing groups in the compiled pattern (excludes
        non-capturing groups). Group 0 = full match is NOT counted."""
        var n = self._lib.lib.call["re2m_num_capturing_groups", Int32](self._re)
        return Int(n)

    def _do_match(
        self, text: String, pos: Int, anchor: Int32
    ) raises -> Optional[Match]:
        # nmatch slots: 1 for group 0 (full match) + N for capturing groups.
        var ncaps = self._lib.lib.call["re2m_num_capturing_groups", Int32](self._re)
        var nmatch = Int(ncaps) + 1
        # Each re2m_string_t slot is 16 bytes on x86-64 (8-byte ptr + 4-byte int + 4 padding).
        var slot_bytes = 16
        var buf_size = slot_bytes * nmatch
        var buf = alloc[UInt8](buf_size)

        var text_len = text.byte_length()
        var endpos = text_len  # whole-string scan after pos
        var ok = self._lib.lib.call["re2m_match", Int32](
            self._re,
            text.unsafe_ptr(),
            text_len,
            pos,
            endpos,
            anchor,
            buf,  # re2m_string_t* match[]
            Int32(nmatch),
        )
        if Int(ok) == 0:
            buf.free()
            var none_result: Optional[Match] = None
            return none_result^

        # Each re2m_string_t slot is { data: char*, length: int }.
        # Read each slot, compute start/end relative to text base, eagerly copy
        # captured bytes into an owned String.
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

        buf.free()
        return Match(captures^, spans^)
