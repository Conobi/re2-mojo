# Pattern — single-owner regex handle. Movable, NOT Copyable.
# Wraps cre2_regexp_t* via UnsafePointer[NoneType, MutAnyOrigin].
# __del__(deinit self) calls cre2_delete.
#
# Cannot be stored in stdlib List (which requires Copyable). For collections,
# use compile_shared() (Task 14) to get a SharedPattern instead.

from std.ffi import external_call
from std.memory import UnsafePointer
from re2_mojo._ffi import (
    _Cre2Lib,
    CreOptionsPtr,
    CreRegexpPtr,
    CRE2_UTF8,
)
from re2_mojo.errors import compile_error
from re2_mojo.flags import CompileFlags


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
