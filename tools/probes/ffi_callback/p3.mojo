from std.ffi import OwnedDLHandle

trait Source:
    def read(mut self, buf: OpaquePointer[MutUntrackedOrigin], n: Int) -> Int: ...

struct Counter(Source, Movable):
    var next: UInt8
    def __init__(out self, start: UInt8):
        self.next = start
    def read(mut self, buf: OpaquePointer[MutUntrackedOrigin], n: Int) -> Int:
        var p = buf.unsafe_bitcast[UInt8]()
        for i in range(n):
            p[unsafe_offset=i] = self.next
            self.next += 1
        return n

struct Halver(Source, Movable):
    var calls: Int
    def __init__(out self):
        self.calls = 0
    def read(mut self, buf: OpaquePointer[MutUntrackedOrigin], n: Int) -> Int:
        self.calls += 1
        var p = buf.unsafe_bitcast[UInt8]()
        for i in range(n // 2):
            p[unsafe_offset=i] = 200
        return n // 2

def tramp[S: Source](user: OpaquePointer[MutUntrackedOrigin], buf: OpaquePointer[MutUntrackedOrigin], n: UInt, got: OpaquePointer[MutUntrackedOrigin]) -> Int32:
    var s = user.unsafe_bitcast[S]()
    got.unsafe_bitcast[UInt]()[unsafe_offset=0] = UInt(s[].read(buf, Int(n)))
    return 0

def register[S: Source](lib: OwnedDLHandle, mut src: S):
    var user = Pointer(to=src).unsafe_bitcast[NoneType]()
    lib.call["store", NoneType](tramp[S], OpaquePointer[MutUntrackedOrigin](unsafe_from_address=Int(user)))

def pull(lib: OwnedDLHandle, mut buf: List[UInt8], on_thread: Bool) -> String:
    var got: List[UInt] = [0]
    var n = len(buf)
    var rc: Int32
    if on_thread:
        rc = lib.call["call_stored_on_thread", Int32](buf.unsafe_ptr(), UInt(n), got.unsafe_ptr())
    else:
        rc = lib.call["call_stored", Int32](buf.unsafe_ptr(), UInt(n), got.unsafe_ptr())
    return String("rc=", rc, " got=", got[0])

def main() raises:
    var lib = OwnedDLHandle("build/probes/libprobe_cb.so")
    var c = Counter(10)
    register(lib, c)
    var b1 = List[UInt8](length=4, fill=0)
    print("P3a Counter stored", pull(lib, b1, False), "buf=", b1[0], b1[3], "state.next=", c.next)
    var b2 = List[UInt8](length=3, fill=0)
    print("P3b Counter thread", pull(lib, b2, True), "buf=", b2[0], b2[2], "state.next=", c.next)
    var h = Halver()
    register(lib, h)
    var b3 = List[UInt8](length=6, fill=0)
    print("P3c Halver thread", pull(lib, b3, True), "buf=", b3[0], b3[2], b3[3], "calls=", h.calls)
    print("c still alive next=", c.next)
