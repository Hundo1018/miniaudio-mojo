"""Audio code you write in Mojo and miniaudio calls: the `NodeProcessor` trait.

A `UserNode[P]` (miniaudio.node) is a node in a graph, the engine's included,
whose processing is `P.process`. With no input bus it is a source (a
synthesizer); with one it is an effect. miniaudio calls `process` from whichever
thread reads the graph: the audio thread of a device, or the caller of
`Engine.render` / `NodeGraph.read`. So `process` must not block, must not raise
(it cannot: nothing could catch it there), and must not call back into the graph.

    struct Saw(NodeProcessor):
        var phase: UInt32
        def process(mut self, input: Span[Float32, ImmutAnyOrigin],
                    output: Span[Float32, MutAnyOrigin], frame_count: Int, channels: Int):
            for i in range(frame_count):
                var v = Float32(Int(self.phase >> 16)) / 32768.0 - 1.0
                self.phase += 1 << 12
                for c in range(channels):
                    output[i * channels + c] = v
"""


trait NodeProcessor(Movable, Deinitable):
    """The processing of a `UserNode`. Implementations own their state; the node
    keeps the processor on the heap, reachable through `UserNode.processor()`, and
    destroys it once, after the node is uninitialised."""

    def process(
        mut self,
        input: Span[Float32, ImmutAnyOrigin],
        output: Span[Float32, MutAnyOrigin],
        frame_count: Int,
        channels: Int,
    ):
        """Write `frame_count` interleaved frames of `channels` samples into
        `output` (every sample: the buffer is not cleared first). `input` is the
        input bus for an effect node, `frame_count * channels` samples or empty
        when nothing is attached; it is always empty for a source node."""
        ...


trait UserDataSource(Movable, Deinitable):
    """Frames you generate or decode yourself, playable anywhere a data source is
    (a `Sound`, a `DataSourceNode`, a chain): `DataSource.from_user`.

    Frames are f32, interleaved, at the channel count and sample rate given to
    `from_user`. miniaudio calls these from whichever thread reads the source, so
    the same rules as `NodeProcessor.process` apply: no blocking, no raising.
    """

    def read(mut self, output: Span[Float32, MutAnyOrigin], frame_count: Int, channels: Int) -> Int:
        """Write up to `frame_count` frames into `output`; return how many. Fewer
        than asked for means the end of the data."""
        ...

    def seek(mut self, frame: UInt64) -> Bool:
        """Move to `frame`; False if that is not possible (a bad seek)."""
        ...

    def length(mut self) -> UInt64:
        """Total frames, or 0 if not known."""
        ...
