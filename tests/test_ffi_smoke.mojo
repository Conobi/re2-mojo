# Smoke: libcre2.so loads via OwnedDLHandle and cre2_version_string is callable.
# Confirms (a) install.sh succeeded, (b) Mojo MCP runner can dlopen system libs,
# (c) the FFI primitives we'll use everywhere else work.

from std.ffi import OwnedDLHandle
from std.memory import UnsafePointer

def main() raises:
    var lib = OwnedDLHandle("libcre2.so")
    if not lib.check_symbol("cre2_version_string"):
        raise Error("cre2_version_string symbol missing — is libcre2 installed?")
    var ver_ptr = lib.call[
        "cre2_version_string", UnsafePointer[UInt8, MutAnyOrigin]
    ]()
    if not ver_ptr:
        raise Error("cre2_version_string returned null")
    var ver = String(unsafe_from_utf8_ptr=ver_ptr)
    print("cre2 version:", ver)
    print("PASS: test_ffi_smoke")
