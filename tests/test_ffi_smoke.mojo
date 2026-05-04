from std.ffi import OwnedDLHandle
from std.memory import UnsafePointer
from re2_mojo._ffi import _Re2mLib, open_lib

def test_owned_dlhandle_directly() raises:
    # Direct OwnedDLHandle smoke test on the shim, independent of _Re2mLib.
    # Mojo MCP does NOT propagate LD_LIBRARY_PATH, so use the absolute path.
    var lib = OwnedDLHandle("/home/donokami/Projets/perso/re2-mojo/lib/libre2_mojo.so")
    if not lib.check_symbol("re2m_opt_new"):
        raise Error("re2m_opt_new symbol missing")
    print("libre2_mojo loaded; re2m_opt_new symbol present")

def test_open_lib_succeeds() raises:
    var l = open_lib()
    print("open_lib OK; all required symbols present")

def main() raises:
    test_owned_dlhandle_directly()
    test_open_lib_succeeds()
    print("PASS: test_ffi_smoke")
