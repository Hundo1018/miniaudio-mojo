from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioPcmRingBufferHandle
from miniaudio_result_utils import format_result_error


def run_pcm_rb_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.pcm_rb_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "pcm ring buffer smoke failed", result))

    print("pcm ring buffer smoke ok")


def run_pcm_rb_overflow_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.pcm_rb_overflow_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "pcm ring buffer overflow smoke failed", result))

    print("pcm ring buffer overflow smoke ok")


def run_pcm_rb_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.pcm_rb_invalid_args_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "pcm ring buffer invalid-args smoke failed", result))

    print("pcm ring buffer invalid-args smoke ok")


def run_pcm_rb_handle_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var rb = MiniAudioPcmRingBufferHandle(bridge)

    try:
        rb.init_f32(bridge, 2, 16, 48000)

        var read_available = rb.available_read(bridge)
        var write_available = rb.available_write(bridge)

        if read_available != 0:
            raise Error("new ring buffer should have 0 readable frames")

        if write_available == 0:
            raise Error("new ring buffer should have writable frames")

        rb.reset(bridge)
    finally:
        rb.close(bridge)

    print("pcm ring buffer handle smoke ok")
