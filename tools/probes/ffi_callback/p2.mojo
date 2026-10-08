from std.ffi import OwnedDLHandle

def fill7(user: OpaquePointer[MutUntrackedOrigin], buf: OpaquePointer[MutUntrackedOrigin], n: UInt, got: OpaquePointer[MutUntrackedOrigin]) -> Int32:
    got.unsafe_bitcast[UInt]()[unsafe_offset=0] = n
    return 0

def main() raises:
    var lib = OwnedDLHandle("build/probes/libprobe_cb.so")
    var f = fill7
    var got: List[UInt] = [0]
    var buf: List[UInt8] = [0]
    var rc = lib.call["call_now", Int32](f, OpaquePointer[MutUntrackedOrigin](unsafe_from_address=Int(0)), buf.unsafe_ptr(), UInt(1), got.unsafe_ptr())
    print("P2 rc=", rc, "got=", got[0])
