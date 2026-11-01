"""Sound end handlers, and the frame pumps that drive them, for the end-callback tests.

Each handler reports through shared atomics the test owns: `fired` counts
`on_end` calls, `destroyed` counts destructor runs. Atomics, because in a real
playback `on_end` runs on the audio thread while the test reads from its own.

The pumps live here, not in the test modules: a module-level function that takes
an `ArcPointer[Atomic[Int]]` makes the compiler crash when `TestSuite` reflects over
the module that defines it (Mojo 1.1.0).
"""

from std.atomic import Atomic
from std.memory import ArcPointer

from miniaudio import Engine
from miniaudio._lib import MaLib
from miniaudio.sound import SoundEndHandler
import miniaudio._ffi.engine_raw as eraw


comptime Count = ArcPointer[Atomic[Int]]


def counter() -> Count:
    return ArcPointer(Atomic[Int](0))


def count(c: Count) -> Int:
    return c[].load()


struct Tally(SoundEndHandler):
    """Adds 1 to `fired` per `on_end`, and 1 to `destroyed` when it is destroyed."""

    var fired: Count
    var destroyed: Count

    def __init__(out self, fired: Count, destroyed: Count):
        self.fired = fired.copy()
        self.destroyed = destroyed.copy()

    def on_end(mut self):
        _ = self.fired[].fetch_add(1)

    def __deinit__(deinit self):
        _ = self.destroyed[].fetch_add(1)


struct Marker(SoundEndHandler):
    """A second handler type: adds `value` to `mark` per `on_end`.

    Replacing a `Tally` with a `Marker` checks that each handler is run, and
    destroyed, as its own type.
    """

    var mark: Count
    var value: Int
    var destroyed: Count

    def __init__(out self, mark: Count, value: Int, destroyed: Count):
        self.mark = mark.copy()
        self.value = value
        self.destroyed = destroyed.copy()

    def on_end(mut self):
        _ = self.mark[].fetch_add(self.value)

    def __deinit__(deinit self):
        _ = self.destroyed[].fetch_add(1)


struct Busy(SoundEndHandler):
    """Takes a while in `on_end` and notes if it is destroyed while that is going on.

    Stands in for a handler that does real work on the audio thread. `running` is
    this instance's own flag: raised for the whole of `on_end`, checked when the
    handler is destroyed. A destroy that sees it raised (counted in `bad`) is exactly
    the use-after-free the shim's lock exists to prevent.
    """

    var fired: Count
    var destroyed: Count
    var bad: Count
    var running: Count
    var work: Count

    def __init__(out self, fired: Count, destroyed: Count, bad: Count):
        self.fired = fired.copy()
        self.destroyed = destroyed.copy()
        self.bad = bad.copy()
        self.running = counter()
        self.work = counter()

    def on_end(mut self):
        _ = self.running[].fetch_add(1)
        for _ in range(60000):
            _ = self.work[].fetch_add(1)
        _ = self.fired[].fetch_add(1)
        _ = self.running[].fetch_sub(1)

    def __deinit__(deinit self):
        if self.running[].load() != 0:
            _ = self.bad[].fetch_add(1)
        _ = self.destroyed[].fetch_add(1)


comptime PERIOD: Int = 480    # frames the engine renders per pass (10 ms at 48 kHz)


def read_periods(eng: ArcPointer[Engine], periods: Int) raises:
    """Pulls `periods` whole periods from a (stopped) engine; handlers run on this thread."""
    var out = List[Float32]()
    for _ in range(periods):
        _ = eng[].read(out, UInt64(PERIOD))


def periods_until_fired(
    eng: ArcPointer[Engine], fired: Count, limit: Int = 16
) raises -> Int:
    """Reads periods until `fired` moves; returns how many it took (limit + 1: never)."""
    var out = List[Float32]()
    for n in range(1, limit + 1):
        _ = eng[].read(out, UInt64(PERIOD))
        if count(fired) > 0:
            return n
    return limit + 1


def raw_read_periods(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], periods: Int
) raises:
    """`read_periods` for a raw engine handle (stereo)."""
    var buf = List[Float32](length=PERIOD * 2, fill=Float32(0))
    for _ in range(periods):
        _ = eraw.engine_read_pcm_frames(lib, eng, buf, UInt64(PERIOD))


def raw_periods_until_fired(
    lib: MaLib, eng: OpaquePointer[MutUntrackedOrigin], fired: Count, limit: Int = 16
) raises -> Int:
    var buf = List[Float32](length=PERIOD * 2, fill=Float32(0))
    for n in range(1, limit + 1):
        _ = eraw.engine_read_pcm_frames(lib, eng, buf, UInt64(PERIOD))
        if count(fired) > 0:
            return n
    return limit + 1
