# Private FFI layer for re2-mojo. Centralizes:
#   - OwnedDLHandle on libcre2.so (one per-process)
#   - Opaque-pointer type aliases for cre2's three opaque types
#   - check_symbol-gated wrappers around every cre2_* call we use
#
# Why centralize: missing symbols ABORT the Mojo process per Topic 1
# (research/topic-1-mojo-ffi-primitives.md). Every dlhandle.call must be gated.
# Doing it once here keeps the public API code clean.

from std.ffi import OwnedDLHandle, external_call
from std.memory import UnsafePointer

# Opaque-pointer aliases. cre2 exposes three opaque types:
#   cre2_options_t  — compile-time options bundle
#   cre2_regexp_t   — compiled regex
#   cre2_string_t   — { const char* data; int length; } returned slice
#                     (we model the *contents* via direct pointer arithmetic
#                      after the call; we don't need a typed wrapper here)
#
# All three are passed across the FFI as void*. Spell them out as
# UnsafePointer[NoneType, MutAnyOrigin] (Topic 1 noted bare UnsafePointer[NoneType]
# fails origin inference).
comptime CreOptionsPtr = UnsafePointer[NoneType, MutAnyOrigin]
comptime CreRegexpPtr = UnsafePointer[NoneType, MutAnyOrigin]
comptime CreStringPtr = UnsafePointer[NoneType, MutAnyOrigin]
comptime CCharPtr = UnsafePointer[UInt8, MutAnyOrigin]
comptime CIntPtr = UnsafePointer[Int32, MutAnyOrigin]

# cre2 anchor constants — match cre2.h (CRE2_UNANCHORED=1, ANCHOR_START=2, ANCHOR_BOTH=3)
# NB: cre2's enum starts at 1, not 0 — verified against /usr/local/include/cre2.h.
comptime CRE2_UNANCHORED: Int32 = 1
comptime CRE2_ANCHOR_START: Int32 = 2
comptime CRE2_ANCHOR_BOTH: Int32 = 3

# cre2 encoding constants (CRE2_UTF8=1, CRE2_Latin1=2)
comptime CRE2_UTF8: Int32 = 1


struct _Cre2Lib(Movable):
    """Singleton-ish wrapper around the libcre2 DLHandle. Constructed on first
    Pattern compile. Validates every symbol we use exists; raises if not.
    This is the only place we call OwnedDLHandle — every other module imports
    this one."""

    var lib: OwnedDLHandle

    def __init__(out self) raises:
        self.lib = OwnedDLHandle("libcre2.so")
        # Gate every symbol we'll use. Missing symbols would ABORT the process,
        # so check up-front and raise a clean Mojo Error instead.
        var required: List[String] = [
            String("cre2_new"),
            String("cre2_delete"),
            String("cre2_match"),
            String("cre2_error_code"),
            String("cre2_error_string"),
            String("cre2_num_capturing_groups"),
            String("cre2_opt_new"),
            String("cre2_opt_delete"),
            String("cre2_opt_set_encoding"),
            String("cre2_opt_set_log_errors"),
            String("cre2_opt_set_one_line"),
            String("cre2_opt_set_case_sensitive"),
            String("cre2_opt_set_dot_nl"),
            String("cre2_replace_re"),
            String("cre2_global_replace_re"),
        ]
        for i in range(len(required)):
            var sym = required[i]
            if not self.lib.check_symbol(sym):
                raise Error("re2-mojo: required cre2 symbol missing: " + sym)


# Module-level lazy init helper. We construct the lib singleton on first use
# (i.e. inside compile() / compile_shared()) so that loading re2_mojo's modules
# at import time doesn't open libcre2 unless someone actually uses it.
# In Mojo 0.26.x there's no module-level `var` with init; the canonical idiom
# is a function that constructs and returns by value (caller stores it).
def open_lib() raises -> _Cre2Lib:
    return _Cre2Lib()
