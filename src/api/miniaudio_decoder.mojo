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

    var probe_read = bridge.decoder_read_probe_f32(decoder, 1024)
    if probe_read < 0:
        _ = bridge.decoder_uninit(decoder)
        bridge.decoder_destroy(decoder)
        var probe_error = Int(probe_read)
        raise Error(
            "decoder read probe failed: "
            + bridge.result_description(probe_error)
            + " ("
            + String(probe_error)
            + ")"
        )

    print("decoder smoke ok (init + seek + read + cleanup), frames:", probe_read)

    _ = bridge.decoder_uninit(decoder)
    bridge.decoder_destroy(decoder)