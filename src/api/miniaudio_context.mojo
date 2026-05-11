from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioContextHandle


def run_context_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var context = MiniAudioContextHandle(bridge)
    try:
        context.init_default(bridge)
        context.uninit(bridge)
    except e:
        context.close(bridge)
        raise e^

    context.close(bridge)
    print("context smoke ok (create + init + uninit + destroy)")
