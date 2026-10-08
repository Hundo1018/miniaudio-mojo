from std.ffi import OwnedDLHandle

comptime Opaque = OpaquePointer[MutUntrackedOrigin]
comptime MA_AT_END: Int32 = -17

def null() -> Opaque:
    return Opaque(unsafe_from_address=Int(0))

trait ReadSeek:
    def read(mut self, dst: Opaque, n: Int) -> Int: ...
    def seek(mut self, offset: Int64, origin: Int) -> Bool: ...

struct BytesStream(ReadSeek, Movable):
    var data: List[UInt8]
    var pos: Int
    var reads: Int
    def __init__(out self, var data: List[UInt8]):
        self.data = data^
        self.pos = 0
        self.reads = 0
    def read(mut self, dst: Opaque, n: Int) -> Int:
        self.reads += 1
        var k = min(n, len(self.data) - self.pos)
        var p = dst.unsafe_bitcast[UInt8]()
        for i in range(k):
            p[unsafe_offset=i] = self.data[self.pos + i]
        self.pos += k
        return k
    def seek(mut self, offset: Int64, origin: Int) -> Bool:
        var base = 0 if origin == 0 else (self.pos if origin == 1 else len(self.data))
        var target = base + Int(offset)
        if target < 0 or target > len(self.data):
            return False
        self.pos = target
        return True

def read_tramp[S: ReadSeek](user: Opaque, dst: Opaque, n: UInt, got: Opaque) -> Int32:
    var k = user.unsafe_bitcast[S]()[].read(dst, Int(n))
    got.unsafe_bitcast[UInt]()[unsafe_offset=0] = UInt(k)
    return Int32(0) if (k > 0 or n == 0) else MA_AT_END

def seek_tramp[S: ReadSeek](user: Opaque, offset: Int64, origin: Int32) -> Int32:
    return Int32(0) if user.unsafe_bitcast[S]()[].seek(offset, Int(origin)) else Int32(-1)

def open_decoder[S: ReadSeek](lib: OwnedDLHandle, mut src: S) -> Opaque:
    var user = Opaque(unsafe_from_address=Int(Pointer(to=src)))
    var rc: List[Int32] = [0]
    var h = lib.call["probe_decoder_init", Opaque](read_tramp[S], seek_tramp[S], user, rc.unsafe_ptr())
    print("  init rc=", rc[0])
    return h

def main() raises:
    var lib = OwnedDLHandle("build/probes/libprobe_dec.so")
    var path = String("build/test_assets/sine_440_stereo.wav")
    var bytes: List[UInt8]
    with open(path, "r") as f:
        bytes = f.read_bytes()
    var stream = BytesStream(bytes^)
    var h = open_decoder(lib, stream)
    var ch: List[UInt32] = [0]
    var sr: List[UInt32] = [0]
    var ln: List[UInt64] = [0]
    print("  info rc=", lib.call["probe_decoder_info", Int32](h, ch.unsafe_ptr(), sr.unsafe_ptr(), ln.unsafe_ptr()), "ch=", ch[0], "sr=", sr[0], "len=", ln[0])
    var n = 4800
    var got: List[UInt64] = [0]
    var ref_got: List[UInt64] = [0]
    for seek in [UInt64(0), UInt64(24000)]:
        var a = List[Float32](length=n * 2, fill=0)
        var b = List[Float32](length=n * 2, fill=0)
        _ = lib.call["probe_decoder_seek", Int32](h, seek)
        var rc = lib.call["probe_decoder_read", Int32](h, a.unsafe_ptr(), UInt64(n), got.unsafe_ptr())
        var rrc = lib.call["probe_ref_read", Int32](path.unsafe_ptr(), seek, b.unsafe_ptr(), UInt64(n), ref_got.unsafe_ptr())
        var diff = 0
        var peak: Float32 = 0
        for i in range(n * 2):
            if a[i] != b[i]:
                diff += 1
            peak = max(peak, abs(a[i]))
        print("  seek", seek, "read rc=", rc, "got=", got[0], "| ref rc=", rrc, "got=", ref_got[0], "| mismatched samples=", diff, "peak=", peak)
    var tail = List[Float32](length=96000 * 2, fill=0)
    _ = lib.call["probe_decoder_seek", Int32](h, UInt64(47000))
    var trc = lib.call["probe_decoder_read", Int32](h, tail.unsafe_ptr(), UInt64(96000), got.unsafe_ptr())
    print("  read past end: rc=", trc, "got=", got[0], "(expect 1000)")
    lib.call["probe_decoder_uninit", NoneType](h)
    print("  stream callbacks invoked: reads=", stream.reads, "final pos=", stream.pos, "of", len(stream.data))
