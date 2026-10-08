from std.ffi import OwnedDLHandle

def fill7(user: OpaquePointer[MutUntrackedOrigin], buf: OpaquePointer[MutUntrackedOrigin], n: UInt, got: OpaquePointer[MutUntrackedOrigin]) -> Int32:
    var p = buf.unsafe_bitcast[UInt8]()
    for i in range(Int(n)):
        p[unsafe_offset=i] = 7
    got.unsafe_bitcast[UInt]()[unsafe_offset=0] = n
    return 0

def main() raises:
    var lib = OwnedDLHandle("build/probes/libprobe_cb.so")
    var buf: List[UInt8] = [0, 0, 0, 0]
    var got: List[UInt] = [0]
    var rc = lib.call["call_now", Int32](fill7, OpaquePointer[MutUntrackedOrigin](unsafe_from_address=Int(0)), buf.unsafe_ptr(), UInt(4), got.unsafe_ptr())
    print("P1 rc=", rc, "got=", got[0], "buf=", buf[0], buf[3])
