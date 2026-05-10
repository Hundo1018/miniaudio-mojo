from miniaudio_ctypes import MiniAudioCtypes


def run_context_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)

    var context = bridge.context_create()
    if context == null_ptr:
        raise Error("context_create failed")

    var init_result = bridge.context_init_default(context)
    if init_result != 0:
        bridge.context_destroy(context)
        raise Error(
            "context init failed: "
            + bridge.result_description(init_result)
            + " ("
            + String(init_result)
            + ")"
        )

    var uninit_result = bridge.context_uninit(context)
    if uninit_result != 0:
        bridge.context_destroy(context)
        raise Error(
            "context uninit failed: "
            + bridge.result_description(uninit_result)
            + " ("
            + String(uninit_result)
            + ")"
        )

    bridge.context_destroy(context)
    print("context smoke ok (create + init + uninit + destroy)")
