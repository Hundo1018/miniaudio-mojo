from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioContextHandle, MiniAudioEngineHandle


def run_mojo_handle_lifecycle_contract_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var context = MiniAudioContextHandle(bridge)

    # Handle wrappers should safely allow repeated close/uninit paths.
    context.uninit(bridge)
    context.init_default(bridge)
    context.uninit(bridge)
    context.close(bridge)
    context.close(bridge)

    var engine = MiniAudioEngineHandle(bridge)
    engine.uninit(bridge)
    engine.init_default(bridge)
    engine.uninit(bridge)
    engine.close(bridge)
    engine.close(bridge)

    print("mojo handle lifecycle contract smoke ok")
