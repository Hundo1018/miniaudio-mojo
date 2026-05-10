from miniaudio_ctypes import MiniAudioCtypes


def run_decoder_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)

    var decoder = bridge.decoder_create()
    if decoder == null_ptr:
        raise Error("decoder_create failed")

    var init_result = bridge.decoder_init_file_f32(decoder, file_path, 2, 48000)
    if init_result != 0:
        bridge.decoder_destroy(decoder)
        raise Error(
            "decoder init failed: "
            + bridge.result_description(init_result)
            + " ("
            + String(init_result)
            + ")"
        )

    var seek_result = bridge.decoder_seek_to_pcm_frame(decoder, 0)
    if seek_result != 0:
        _ = bridge.decoder_uninit(decoder)
        bridge.decoder_destroy(decoder)
        raise Error(
            "decoder seek failed: "
            + bridge.result_description(seek_result)
            + " ("
            + String(seek_result)
            + ")"
        )

    print("decoder smoke ok (init + seek + cleanup)")

    _ = bridge.decoder_uninit(decoder)
    bridge.decoder_destroy(decoder)