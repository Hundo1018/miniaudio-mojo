from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import (
    MiniAudioEngineHandle,
    MiniAudioBiquadNodeHandle,
)


def run_biquad_peaking_eq_smoke() raises:
    """Biquad peaking EQ smoke test with valid parameters.
    
    Tests: biquad node creation, initialization with peaking EQ config,
    and cleanup. Validates that the node can be created and attached to engine.
    """
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var biquad = MiniAudioBiquadNodeHandle(bridge)

    try:
        # Initialize engine with default config
        engine.init_default(bridge)

        # Initialize biquad node with peaking EQ parameters
        biquad.init_peaking_eq(
            bridge,
            engine,
            channels=2,
            sample_rate=48000,
            gain_db=3.0,
            q=1.0,
            frequency=1000.0,
        )

        # Get the underlying node (validates graph attachment)
        _ = biquad.get_node(bridge)

        print("biquad peaking eq smoke ok (identity filter)")
    finally:
        biquad.close(bridge)
        engine.close(bridge)


def run_biquad_invalid_q_smoke() raises:
    """Biquad smoke test with invalid Q (≤ 0).
    
    Tests: negative path - q parameter validation.
    Should raise an error when q <= 0.
    """
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var biquad = MiniAudioBiquadNodeHandle(bridge)

    try:
        # Initialize engine with default config
        engine.init_default(bridge)

        # Try to initialize biquad with invalid q (should raise)
        var rejected = False
        try:
            biquad.init_peaking_eq(
                bridge,
                engine,
                channels=2,
                sample_rate=48000,
                gain_db=3.0,
                q=-1.0,  # Invalid: q must be positive
                frequency=1000.0,
            )
        except e:
            # Expected: q validation should catch this
            rejected = True

        if rejected:
            print("biquad invalid q smoke ok (rejected q <= 0)")
        else:
            raise Error("biquad should reject q <= 0")

    finally:
        biquad.close(bridge)
        engine.close(bridge)

