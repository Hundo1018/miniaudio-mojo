from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import (
    MiniAudioEngineHandle,
    MiniAudioNotchNodeHandle,
    MiniAudioPeakNodeHandle,
    MiniAudioLoshelfNodeHandle,
    MiniAudioHishelfNodeHandle,
    miniaudio_null_handle,
)
from miniaudio_errors import MA_INVALID_ARGS


def run_notch_node_smoke() raises:
    """Positive-path smoke: create engine, init notch node, reinit, get node pointer."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var notch = MiniAudioNotchNodeHandle(bridge)

    try:
        engine.init_default(bridge)

        # init with 1000 Hz notch, Q=0.707, stereo 44100 Hz
        notch.init(bridge, engine, 2, 44100, 0.707, 1000.0)

        var node_ptr = notch.get_node(bridge)
        if node_ptr == miniaudio_null_handle():
            raise Error("notch node smoke: get_node returned null")

        # reinit with different frequency
        notch.reinit(bridge, 44100, 0.707, 2000.0)

    finally:
        notch.close(bridge)
        engine.close(bridge)

    print("notch node smoke ok")


def run_peak_node_smoke() raises:
    """Positive-path smoke: create engine, init peak EQ node, reinit, get node pointer."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var peak = MiniAudioPeakNodeHandle(bridge)

    try:
        engine.init_default(bridge)

        # +6 dB boost at 1 kHz, Q=0.707, stereo 44100 Hz
        peak.init(bridge, engine, 2, 44100, 6.0, 0.707, 1000.0)

        var node_ptr = peak.get_node(bridge)
        if node_ptr == miniaudio_null_handle():
            raise Error("peak node smoke: get_node returned null")

        # reinit with cut
        peak.reinit(bridge, 44100, -3.0, 0.707, 1000.0)

    finally:
        peak.close(bridge)
        engine.close(bridge)

    print("peak node smoke ok")


def run_loshelf_node_smoke() raises:
    """Positive-path smoke: create engine, init low shelf node, reinit, get node pointer."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var loshelf = MiniAudioLoshelfNodeHandle(bridge)

    try:
        engine.init_default(bridge)

        # +3 dB low shelf at 200 Hz, Q=0.707, stereo 44100 Hz
        loshelf.init(bridge, engine, 2, 44100, 3.0, 0.707, 200.0)

        var node_ptr = loshelf.get_node(bridge)
        if node_ptr == miniaudio_null_handle():
            raise Error("loshelf node smoke: get_node returned null")

        # reinit with cut
        loshelf.reinit(bridge, 44100, -3.0, 0.707, 200.0)

    finally:
        loshelf.close(bridge)
        engine.close(bridge)

    print("loshelf node smoke ok")


def run_hishelf_node_smoke() raises:
    """Positive-path smoke: create engine, init high shelf node, reinit, get node pointer."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var engine = MiniAudioEngineHandle(bridge)
    var hishelf = MiniAudioHishelfNodeHandle(bridge)

    try:
        engine.init_default(bridge)

        # -3 dB high shelf at 8 kHz, Q=0.707, stereo 44100 Hz
        hishelf.init(bridge, engine, 2, 44100, -3.0, 0.707, 8000.0)

        var node_ptr = hishelf.get_node(bridge)
        if node_ptr == miniaudio_null_handle():
            raise Error("hishelf node smoke: get_node returned null")

        # reinit with boost
        hishelf.reinit(bridge, 44100, 3.0, 0.707, 8000.0)

    finally:
        hishelf.close(bridge)
        engine.close(bridge)

    print("hishelf node smoke ok")


def run_eq_nodes_invalid_smoke() raises:
    """Negative-path smoke: all 4 EQ node types reject uninit / bad params."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")

    # notch: uninit handle → uninit returns MA_INVALID_ARGS
    var notch = MiniAudioNotchNodeHandle(bridge)
    var r_notch = bridge.notch_node_uninit(notch.raw)
    notch.close(bridge)
    # -2 from C as Int might be unsigned 4294967294; check for both forms
    if r_notch != MA_INVALID_ARGS and r_notch != 4294967294:
        raise Error(
            "eq_nodes invalid smoke: expected MA_INVALID_ARGS from notch_node_uninit on uninit, got: "
            + String(r_notch)
        )

    # peak: uninit handle → uninit returns MA_INVALID_ARGS
    var peak = MiniAudioPeakNodeHandle(bridge)
    var r_peak = bridge.peak_node_uninit(peak.raw)
    peak.close(bridge)
    # -2 from C as Int might be unsigned 4294967294; check for both forms
    if r_peak != MA_INVALID_ARGS and r_peak != 4294967294:
        raise Error(
            "eq_nodes invalid smoke: expected MA_INVALID_ARGS from peak_node_uninit on uninit, got: "
            + String(r_peak)
        )

    # loshelf: uninit handle → uninit returns MA_INVALID_ARGS
    var loshelf = MiniAudioLoshelfNodeHandle(bridge)
    var r_loshelf = bridge.loshelf_node_uninit(loshelf.raw)
    loshelf.close(bridge)
    # -2 from C as Int might be unsigned 4294967294; check for both forms
    if r_loshelf != MA_INVALID_ARGS and r_loshelf != 4294967294:
        raise Error(
            "eq_nodes invalid smoke: expected MA_INVALID_ARGS from loshelf_node_uninit on uninit, got: "
            + String(r_loshelf)
        )

    # hishelf: uninit handle → uninit returns MA_INVALID_ARGS
    var hishelf = MiniAudioHishelfNodeHandle(bridge)
    var r_hishelf = bridge.hishelf_node_uninit(hishelf.raw)
    hishelf.close(bridge)
    # -2 from C as Int might be unsigned 4294967294; check for both forms
    if r_hishelf != MA_INVALID_ARGS and r_hishelf != 4294967294:
        raise Error(
            "eq_nodes invalid smoke: expected MA_INVALID_ARGS from hishelf_node_uninit on uninit, got: "
            + String(r_hishelf)
        )

    print("eq nodes invalid smoke ok")
