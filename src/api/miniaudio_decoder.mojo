from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioDecoderHandle
from miniaudio_errors import MA_INVALID_ARGS, result_name
from miniaudio_result_utils import format_result_error

comptime MMJ_SAMPLE_FORMAT_U8 = Int(1)
comptime MMJ_SAMPLE_FORMAT_S16 = Int(2)
comptime MMJ_SAMPLE_FORMAT_S24 = Int(3)
comptime MMJ_SAMPLE_FORMAT_S32 = Int(4)
comptime MMJ_SAMPLE_FORMAT_F32 = Int(5)


def _embedded_wav_stereo_2f() -> String:
    return (
        "\x52\x49\x46\x46\x2C\x00\x00\x00"
        "\x57\x41\x56\x45\x66\x6D\x74\x20"
        "\x10\x00\x00\x00\x01\x00\x02\x00"
        "\x40\x1F\x00\x00\x00\x7D\x00\x00"
        "\x04\x00\x10\x00\x64\x61\x74\x61"
        "\x08\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00"
    )


def run_decoder_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var decoder = MiniAudioDecoderHandle(bridge)
    try:
        decoder.init_file_f32(bridge, file_path, 2, 48000)
        decoder.seek_to_pcm_frame(bridge, 0)
        var probe_read = decoder.read_probe_f32(bridge, 1024)
        print("decoder smoke ok (init + seek + read + cleanup), frames:", probe_read)
    except e:
        decoder.close(bridge)
        raise e^

    decoder.close(bridge)


def run_decoder_read_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var decoder = MiniAudioDecoderHandle(bridge)

    try:
        decoder.init_file_f32(bridge, file_path, 2, 48000)

        var frame_count = UInt64(1024)
        var sample_count = Int(frame_count * UInt64(2))
        var buffer = String(" ") * (sample_count * 4)
        decoder.read_frames_f32(bridge, buffer, frame_count)

        var follow_up_probe = bridge.decoder_read_probe_f32(decoder.raw, 1)
        if follow_up_probe < 0:
            var probe_code = Int(follow_up_probe)
            raise Error(format_result_error(bridge, "decoder follow-up probe failed", probe_code))
    except e:
        decoder.close(bridge)
        raise e^

    decoder.close(bridge)
    print("decoder read smoke ok (init + read_frames + follow-up probe)")


def run_decoder_memory_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var decoder = MiniAudioDecoderHandle(bridge)
    var wav_data = _embedded_wav_stereo_2f()

    try:
        decoder.init_memory_f32(bridge, wav_data, UInt64(52), 2, 8000)
        decoder.seek_to_pcm_frame(bridge, 0)
        var probe_read = decoder.read_probe_f32(bridge, 2)
        if probe_read <= 0:
            raise Error("decoder memory smoke read 0 frames")
    except e:
        decoder.close(bridge)
        raise e^

    decoder.close(bridge)
    print("decoder memory smoke ok (init_memory + seek + read)")


def run_decoder_memory_invalid_args_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var result = bridge.decoder_memory_invalid_args_smoke()
    if result != 0:
        raise Error(format_result_error(bridge, "decoder memory invalid-args smoke failed", result))

    print("decoder memory invalid-args smoke ok")


def try_decoder_file_output_format_init(
    bridge: MiniAudioCtypes,
    file_path: String,
    sample_format: Int,
    format_name: String,
) raises -> Bool:
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var decoder = bridge.decoder_create()
    if decoder == null_ptr:
        raise Error("decoder_create failed")

    var init_result = bridge.decoder_init_file_format(decoder, file_path, 2, 48000, sample_format)
    if init_result != 0:
        bridge.decoder_destroy(decoder)
        print("decoder format init unavailable:", format_name, result_name(init_result), "(", init_result, ")")
        return False

    var seek_result = bridge.decoder_seek_to_pcm_frame(decoder, 0)
    if seek_result != 0:
        _ = bridge.decoder_uninit(decoder)
        bridge.decoder_destroy(decoder)
        raise Error(format_result_error(bridge, "decoder format seek failed", seek_result))

    var probe_read = bridge.decoder_read_probe_f32(decoder, 64)
    _ = bridge.decoder_uninit(decoder)
    bridge.decoder_destroy(decoder)

    if probe_read < 0:
        var code = Int(probe_read)
        raise Error(format_result_error(bridge, "decoder format probe failed", code))

    print("decoder format init ok:", format_name, "frames:", probe_read)
    return True


def run_decoder_output_format_matrix_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var decoder = bridge.decoder_create()
    var success_count = Int(0)

    if decoder == null_ptr:
        raise Error("decoder_create failed")

    var invalid_result = bridge.decoder_init_file_format(decoder, file_path, 2, 48000, 999)
    bridge.decoder_destroy(decoder)
    if invalid_result != MA_INVALID_ARGS:
        raise Error(
            "decoder_init_file_format invalid format expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_result)
        )

    if try_decoder_file_output_format_init(bridge, file_path, MMJ_SAMPLE_FORMAT_F32, "f32"):
        success_count += 1
    if try_decoder_file_output_format_init(bridge, file_path, MMJ_SAMPLE_FORMAT_S16, "s16"):
        success_count += 1
    if try_decoder_file_output_format_init(bridge, file_path, MMJ_SAMPLE_FORMAT_S32, "s32"):
        success_count += 1
    if try_decoder_file_output_format_init(bridge, file_path, MMJ_SAMPLE_FORMAT_U8, "u8"):
        success_count += 1
    if try_decoder_file_output_format_init(bridge, file_path, MMJ_SAMPLE_FORMAT_S24, "s24"):
        success_count += 1

    if success_count <= 0:
        raise Error("decoder output format matrix smoke found no supported formats")

    print("decoder output format matrix smoke ok (success_count:", success_count, ")")


def try_decoder_memory_output_format_init(
    bridge: MiniAudioCtypes,
    wav_data: String,
    sample_format: Int,
    format_name: String,
) raises -> Bool:
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var decoder = bridge.decoder_create()
    if decoder == null_ptr:
        raise Error("decoder_create failed")

    var init_result = bridge.decoder_init_memory_format(decoder, wav_data, UInt64(52), 2, 8000, sample_format)
    if init_result != 0:
        bridge.decoder_destroy(decoder)
        print("decoder memory format init unavailable:", format_name, result_name(init_result), "(", init_result, ")")
        return False

    var seek_result = bridge.decoder_seek_to_pcm_frame(decoder, 0)
    if seek_result != 0:
        _ = bridge.decoder_uninit(decoder)
        bridge.decoder_destroy(decoder)
        raise Error(format_result_error(bridge, "decoder memory format seek failed", seek_result))

    var probe_read = bridge.decoder_read_probe_f32(decoder, 2)
    _ = bridge.decoder_uninit(decoder)
    bridge.decoder_destroy(decoder)

    if probe_read < 0:
        var code = Int(probe_read)
        raise Error(format_result_error(bridge, "decoder memory format probe failed", code))

    print("decoder memory format init ok:", format_name, "frames:", probe_read)
    return True


def run_decoder_memory_output_format_matrix_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var wav_data = _embedded_wav_stereo_2f()
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var decoder = bridge.decoder_create()
    var success_count = Int(0)

    if decoder == null_ptr:
        raise Error("decoder_create failed")

    var invalid_result = bridge.decoder_init_memory_format(decoder, wav_data, UInt64(52), 2, 8000, 999)
    bridge.decoder_destroy(decoder)
    if invalid_result != MA_INVALID_ARGS:
        raise Error(
            "decoder_init_memory_format invalid format expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_result)
        )

    if try_decoder_memory_output_format_init(bridge, wav_data, MMJ_SAMPLE_FORMAT_F32, "f32"):
        success_count += 1
    if try_decoder_memory_output_format_init(bridge, wav_data, MMJ_SAMPLE_FORMAT_S16, "s16"):
        success_count += 1
    if try_decoder_memory_output_format_init(bridge, wav_data, MMJ_SAMPLE_FORMAT_S32, "s32"):
        success_count += 1
    if try_decoder_memory_output_format_init(bridge, wav_data, MMJ_SAMPLE_FORMAT_U8, "u8"):
        success_count += 1
    if try_decoder_memory_output_format_init(bridge, wav_data, MMJ_SAMPLE_FORMAT_S24, "s24"):
        success_count += 1

    if success_count <= 0:
        raise Error("decoder memory output format matrix smoke found no supported formats")

    print("decoder memory output format matrix smoke ok (success_count:", success_count, ")")


def run_decoder_vfs_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var decoder = MiniAudioDecoderHandle(bridge)
    try:
        decoder.init_file_vfs_f32(bridge, file_path, 2, 48000)
        decoder.seek_to_pcm_frame(bridge, 0)
        var probe_read = decoder.read_probe_f32(bridge, 256)
        if probe_read <= 0:
            raise Error("decoder VFS smoke read 0 frames")
    except e:
        decoder.close(bridge)
        raise e^

    decoder.close(bridge)
    print("decoder VFS smoke ok (init_vfs + seek + read)")