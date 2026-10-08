"""Idiomatic data source API (Layer 3).

`DataSource` is an RAII wrapper around ma_data_source — miniaudio's abstract
audio-source interface. miniaudio implements it with a C vtable, which Mojo
cannot author, so the concrete implementation is shim-owned: a *buffer data
source* over an f32 PCM buffer copied into the handle at construction. That
makes the whole generic ma_data_source_* surface (read, seek, range, loop
point, chaining) reachable from Mojo with no device, engine, or file involved.

`DataSourceNode` attaches a data source to an `Engine`'s node graph. It holds
`ArcPointer`s to both the engine and the source so neither is dropped while the
node is alive; `__deinit__` uninits the node first.
"""

from std.memory import ArcPointer

from miniaudio._lib import MaLib, null_handle
from miniaudio.result import MA_SUCCESS, MA_AT_END
from miniaudio.engine import Engine
import miniaudio._ffi.data_source_raw as raw


@fieldwise_init
struct FrameRange(Copyable, Movable):
    """An inclusive-begin / exclusive-end frame range."""

    var beg: UInt64
    var end: UInt64


@fieldwise_init
struct DataFormat(Copyable, Movable):
    """A data source's output format (ma_format code, channels, sample rate)."""

    var format: Int
    var channels: UInt32
    var sample_rate: UInt32


struct DataSource(Movable):
    """A data source (RAII).

    `from_frames` builds a buffer-backed source that owns its handle and samples.
    `Sound.data_source` returns a *borrowed view* of the source a sound plays
    from instead: the same read / seek / range / loop-point / format calls act on
    it, dropping it leaves the sound alone, and once the sound is gone every call
    on the view raises. A view cannot be chained to another source, backed by a
    `DataSourceNode`, or handed to a `Sound` -- anything that would keep its
    pointer past the view's life is refused. Reading from it while the sound is
    playing competes with the engine's audio thread.
    """

    var _lib: ArcPointer[MaLib]
    var _ptr: OpaquePointer[MutUntrackedOrigin]
    var _channels: UInt32

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        ptr: OpaquePointer[MutUntrackedOrigin],
        channels: UInt32,
    ):
        self._lib = lib^
        self._ptr = ptr
        self._channels = channels

    @staticmethod
    def from_frames(
        lib: ArcPointer[MaLib],
        frames: List[Float32],
        *,
        channels: UInt32 = 1,
        sample_rate: UInt32 = 48000,
    ) raises -> Self:
        """Create a data source over a copy of `frames` (interleaved f32).

        The frame count is derived from len(frames) / channels. The shim copies
        the samples, so `frames` need not outlive the returned source.
        """
        if channels == 0:
            raise Error("data source channels must be > 0")
        if len(frames) == 0:
            raise Error("data source frames must not be empty")
        var frame_count = UInt64(len(frames)) // UInt64(channels)
        if frame_count == 0:
            raise Error("data source frames shorter than one full frame")

        var ptr = raw.data_source_alloc(lib[])
        if ptr == null_handle():
            raise Error("data_source_alloc failed (out of memory)")
        var code = raw.data_source_init_buffer(
            lib[], ptr, frames, frame_count, channels, sample_rate
        )
        if code != MA_SUCCESS:
            raw.data_source_free(lib[], ptr)
            raise Error(lib[].describe("data source init failed", code))
        return Self(lib.copy(), ptr, channels)

    # ---- read / seek --------------------------------------------------------

    def read_frames(mut self, frame_count: UInt64) raises -> List[Float32]:
        """Read up to `frame_count` frames; the result is truncated at the end.

        Reaching the end of the source is not an error — a short (or empty)
        list is returned instead.
        """
        var n = Int(frame_count) * Int(self._channels)
        var buf = List[Float32](capacity=n)
        buf.resize(n, Float32(0))
        var rc = raw.data_source_read_pcm_frames(
            self._lib[], self._ptr, buf, frame_count
        )
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(self._lib[].describe("data source read failed", rc.result))
        buf.resize(Int(rc.value) * Int(self._channels), Float32(0))
        return buf^

    def seek_to_frame(mut self, frame_index: UInt64) raises:
        var code = raw.data_source_seek_to_pcm_frame(
            self._lib[], self._ptr, frame_index
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("data source seek failed", code))

    def seek_frames(mut self, frame_count: UInt64) raises -> UInt64:
        """Forward-only relative seek. Returns the number of frames skipped."""
        var rc = raw.data_source_seek_pcm_frames(
            self._lib[], self._ptr, frame_count
        )
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(
                self._lib[].describe("data source seek_frames failed", rc.result)
            )
        return rc.value

    def seek_seconds(mut self, second_count: Float32) raises -> Float32:
        """Forward-only relative seek in seconds. Returns seconds skipped."""
        var rc = raw.data_source_seek_seconds(
            self._lib[], self._ptr, second_count
        )
        if rc.result != MA_SUCCESS and rc.result != MA_AT_END:
            raise Error(
                self._lib[].describe("data source seek_seconds failed", rc.result)
            )
        return rc.value

    def seek_to_second(mut self, seek_point: Float32) raises:
        var code = raw.data_source_seek_to_second(
            self._lib[], self._ptr, seek_point
        )
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source seek_to_second failed", code)
            )

    # ---- queries ------------------------------------------------------------

    def data_format(self) raises -> DataFormat:
        var rc = raw.data_source_get_data_format(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source data_format failed", rc.result)
            )
        return DataFormat(rc.format, rc.channels, rc.sample_rate)

    def cursor_frames(self) raises -> UInt64:
        var rc = raw.data_source_get_cursor_in_pcm_frames(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("data source cursor failed", rc.result))
        return rc.value

    def length_frames(self) raises -> UInt64:
        var rc = raw.data_source_get_length_in_pcm_frames(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("data source length failed", rc.result))
        return rc.value

    def cursor_seconds(self) raises -> Float32:
        var rc = raw.data_source_get_cursor_in_seconds(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source cursor_seconds failed", rc.result)
            )
        return rc.value

    def length_seconds(self) raises -> Float32:
        var rc = raw.data_source_get_length_in_seconds(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source length_seconds failed", rc.result)
            )
        return rc.value

    # ---- looping ------------------------------------------------------------

    def set_looping(mut self, is_looping: Bool) raises:
        var code = raw.data_source_set_looping(self._lib[], self._ptr, is_looping)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("data source set_looping failed", code))

    def is_looping(self) -> Bool:
        return raw.data_source_is_looping(self._lib[], self._ptr)

    # ---- range / loop point -------------------------------------------------

    def set_range(mut self, beg: UInt64, end: UInt64) raises:
        """Restrict reads to [beg, end). The cursor is clamped into the range."""
        var code = raw.data_source_set_range_in_pcm_frames(
            self._lib[], self._ptr, beg, end
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("data source set_range failed", code))

    def range(self) raises -> FrameRange:
        var rc = raw.data_source_get_range_in_pcm_frames(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("data source range failed", rc.result))
        return FrameRange(rc.beg, rc.end)

    def set_loop_point(mut self, beg: UInt64, end: UInt64) raises:
        """Set where a looping read wraps back to."""
        var code = raw.data_source_set_loop_point_in_pcm_frames(
            self._lib[], self._ptr, beg, end
        )
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source set_loop_point failed", code)
            )

    def loop_point(self) raises -> FrameRange:
        var rc = raw.data_source_get_loop_point_in_pcm_frames(
            self._lib[], self._ptr
        )
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source loop_point failed", rc.result)
            )
        return FrameRange(rc.beg, rc.end)

    # ---- chaining -----------------------------------------------------------

    def set_current(mut self, ref other: DataSource) raises:
        """Read through `other` instead of self."""
        var code = raw.data_source_set_current(
            self._lib[], self._ptr, other._ptr
        )
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("data source set_current failed", code))

    def reset_current(mut self) raises:
        """Restore the post-init default of reading from self.

        Note this passes the source itself, not null: miniaudio treats a null
        current as "no current source", not as "read from self".
        """
        var code = raw.data_source_set_current(self._lib[], self._ptr, self._ptr)
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source reset_current failed", code)
            )

    def current_is(self, ref other: DataSource) raises -> Bool:
        """Whether the current source is `other` (identity comparison)."""
        var rc = raw.data_source_current_is(self._lib[], self._ptr, other._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source current_is failed", rc.result)
            )
        return rc.value

    def current_is_self(self) raises -> Bool:
        var rc = raw.data_source_current_is(self._lib[], self._ptr, self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source current_is failed", rc.result)
            )
        return rc.value

    def set_next(mut self, ref other: DataSource) raises:
        """Chain `other` to play after this source is exhausted."""
        var code = raw.data_source_set_next(self._lib[], self._ptr, other._ptr)
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("data source set_next failed", code))

    def clear_next(mut self) raises:
        var code = raw.data_source_set_next(self._lib[], self._ptr, null_handle())
        if code != MA_SUCCESS:
            raise Error(self._lib[].describe("data source clear_next failed", code))

    def next_is(self, ref other: DataSource) raises -> Bool:
        var rc = raw.data_source_next_is(self._lib[], self._ptr, other._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("data source next_is failed", rc.result))
        return rc.value

    def has_next(self) raises -> Bool:
        """Whether a next source is chained (i.e. next is not null)."""
        var rc = raw.data_source_next_is(self._lib[], self._ptr, null_handle())
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("data source next_is failed", rc.result))
        return not rc.value

    def set_next_callback(mut self, ref other: DataSource) raises:
        """Install the shim-owned next-callback, resolving to `other`."""
        var code = raw.data_source_set_next_callback(
            self._lib[], self._ptr, other._ptr
        )
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source set_next_callback failed", code)
            )

    def clear_next_callback(mut self) raises:
        var code = raw.data_source_set_next_callback(
            self._lib[], self._ptr, null_handle()
        )
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source clear_next_callback failed", code)
            )

    def has_next_callback(self) raises -> Bool:
        var rc = raw.data_source_has_next_callback(self._lib[], self._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(
                self._lib[].describe(
                    "data source has_next_callback failed", rc.result
                )
            )
        return rc.value

    def is_same(self, other: DataSource) raises -> Bool:
        """Whether both handles stand for the same underlying data source.

        A view of a sound's data source (`Sound.data_source`) is the same source
        as the one the sound was built from.
        """
        var rc = raw.data_source_is_same(self._lib[], self._ptr, other._ptr)
        if rc.result != MA_SUCCESS:
            raise Error(self._lib[].describe("data source identity failed", rc.result))
        return rc.value

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.data_source_free(self._lib[], self._ptr)


struct DataSourceNode(Movable):
    """A node-graph node pulling from a `DataSource` (RAII).

    Holds the engine and the source alive for its own lifetime.
    """

    var _lib: ArcPointer[MaLib]
    var _engine: ArcPointer[Engine]
    var _source: ArcPointer[DataSource]
    var _ptr: OpaquePointer[MutUntrackedOrigin]

    def __init__(
        out self,
        var lib: ArcPointer[MaLib],
        var engine: ArcPointer[Engine],
        var source: ArcPointer[DataSource],
        ptr: OpaquePointer[MutUntrackedOrigin],
    ):
        self._lib = lib^
        self._engine = engine^
        self._source = source^
        self._ptr = ptr

    @staticmethod
    def create(
        engine: ArcPointer[Engine], source: ArcPointer[DataSource]
    ) raises -> Self:
        var lib = engine[]._lib.copy()
        var ptr = raw.data_source_node_alloc(lib[])
        if ptr == null_handle():
            raise Error("data_source_node_alloc failed (out of memory)")
        var code = raw.data_source_node_init(
            lib[], ptr, engine[]._ptr, source[]._ptr
        )
        if code != MA_SUCCESS:
            raw.data_source_node_free(lib[], ptr)
            raise Error(lib[].describe("data source node init failed", code))
        return Self(lib^, engine.copy(), source.copy(), ptr)

    def set_looping(mut self, is_looping: Bool) raises:
        var code = raw.data_source_node_set_looping(
            self._lib[], self._ptr, is_looping
        )
        if code != MA_SUCCESS:
            raise Error(
                self._lib[].describe("data source node set_looping failed", code)
            )

    def is_looping(self) -> Bool:
        return raw.data_source_node_is_looping(self._lib[], self._ptr)

    def __deinit__(deinit self):
        if self._ptr != null_handle():
            raw.data_source_node_free(self._lib[], self._ptr)
