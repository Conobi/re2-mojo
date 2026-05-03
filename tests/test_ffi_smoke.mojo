from std.ffi import OwnedDLHandle
from std.memory import UnsafePointer
from re2_mojo._ffi import _Cre2Lib, open_lib

def test_owned_dlhandle_directly() raises:
    var lib = OwnedDLHandle("libcre2.so")
    if not lib.check_symbol("cre2_version_string"):
        raise Error("cre2_version_string symbol missing")
    var ver_ptr = lib.call[
        "cre2_version_string", UnsafePointer[UInt8, MutAnyOrigin]
    ]()
    if not ver_ptr:
        raise Error("cre2_version_string returned null")
    var ver = String(unsafe_from_utf8_ptr=ver_ptr)
    print("cre2 version:", ver)

def test_open_lib_succeeds() raises:
    var l = open_lib()
    print("open_lib OK; all required symbols present")

def main() raises:
    test_owned_dlhandle_directly()
    test_open_lib_succeeds()
    print("PASS: test_ffi_smoke")
