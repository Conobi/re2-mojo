# Private FFI layer for re2-mojo. Centralizes:
#   - OwnedDLHandle on libre2_mojo.so (one per-process)
#   - Opaque-pointer type aliases for our three opaque types
#   - check_symbol-gated wrappers around every re2m_* call we use
#
# Why centralize: missing symbols ABORT the Mojo process per Topic 1
# (research/topic-1-mojo-ffi-primitives.md). Every dlhandle.call must be gated.
# Doing it once here keeps the public API code clean.

from std.ffi import OwnedDLHandle, external_call
from std.memory import UnsafePointer

# Opaque-pointer aliases. The shim exposes three opaque types:
#   re2m_options_t  — compile-time options bundle
#   re2m_regexp_t   — compiled regex
#   re2m_string_t   — { const char* data; int32_t length; int32_t _padding; }
#                     returned slice (16 bytes on LP64, layout locked by
#                     static_assert in libre2_mojo.cc; we model the *contents*
#                     via direct pointer arithmetic after the call)
#
# All three are passed across the FFI as void*. Spell them out as
# UnsafePointer[NoneType, MutAnyOrigin] (Topic 1 noted bare UnsafePointer[NoneType]
# fails origin inference).
comptime Re2mOptionsPtr = UnsafePointer[NoneType, MutAnyOrigin]
comptime Re2mRegexpPtr = UnsafePointer[NoneType, MutAnyOrigin]
comptime Re2mStringPtr = UnsafePointer[NoneType, MutAnyOrigin]
comptime CCharPtr = UnsafePointer[UInt8, MutAnyOrigin]
comptime CIntPtr = UnsafePointer[Int32, MutAnyOrigin]

# Anchor constants — match libre2_mojo.h (RE2M_UNANCHORED=1, ANCHOR_START=2,
# ANCHOR_BOTH=3). Inherited from cre2's public values; the shim translates
# to RE2's internal enum (0/1/2) inside re2m_match.
comptime RE2M_UNANCHORED: Int32 = 1
comptime RE2M_ANCHOR_START: Int32 = 2
comptime RE2M_ANCHOR_BOTH: Int32 = 3

# Encoding constants (RE2M_UTF8=1, RE2M_LATIN1=2)
comptime RE2M_UTF8: Int32 = 1


struct _Re2mLib(Movable):
    """Singleton-ish wrapper around the libre2_mojo DLHandle. Constructed on
    first Pattern compile. Validates every symbol we use exists; raises if not.
    This is the only place we call OwnedDLHandle — every other module imports
    this one."""

    var lib: OwnedDLHandle

    def __init__(out self) raises:
        # Absolute path: Mojo MCP does NOT propagate LD_LIBRARY_PATH, so the
        # short-name form (`OwnedDLHandle("libre2_mojo.so")`) fails to resolve.
        # The shim ships at <repo>/lib/libre2_mojo.so; hardcode the canonical
        # development checkout path here (see CLAUDE.md / README for the
        # project layout assumption).
        self.lib = OwnedDLHandle("/home/donokami/Projets/perso/re2-mojo/lib/libre2_mojo.so")
        # Gate every symbol we'll use. Missing symbols would ABORT the process,
        # so check up-front and raise a clean Mojo Error instead.
        var required: List[String] = [
            String("re2m_new"),
            String("re2m_delete"),
            String("re2m_match"),
            String("re2m_error_code"),
            String("re2m_error_string"),
            String("re2m_num_capturing_groups"),
            String("re2m_opt_new"),
            String("re2m_opt_delete"),
            String("re2m_opt_set_encoding"),
            String("re2m_opt_set_log_errors"),
            String("re2m_opt_set_case_sensitive"),
            String("re2m_opt_set_dot_nl"),
        ]
        for i in range(len(required)):
            var sym = required[i]
            if not self.lib.check_symbol(sym):
                raise Error("re2-mojo: required re2m symbol missing: " + sym)


# Module-level lazy init helper. We construct the lib singleton on first use
# (i.e. inside compile() / compile_shared()) so that loading re2_mojo's modules
# at import time doesn't open libre2_mojo unless someone actually uses it.
# In Mojo 0.26.x there's no module-level `var` with init; the canonical idiom
# is a function that constructs and returns by value (caller stores it).
def open_lib() raises -> _Re2mLib:
    return _Re2mLib()
