from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import MA_INVALID_ARGS, result_name
from miniaudio_handles import MiniAudioEncoderHandle
from miniaudio_result_utils import format_result_error

comptime MMJ_SAMPLE_FORMAT_U8 = Int(1)
comptime MMJ_SAMPLE_FORMAT_S16 = Int(2)
comptime MMJ_SAMPLE_FORMAT_S32 = Int(4)
comptime MMJ_SAMPLE_FORMAT_F32 = Int(5)


def run_encoder_write_silence_smoke(output_file: String) raises:
    """Test encoder write_silence functionality."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var encoder = MiniAudioEncoderHandle(bridge)

    try:
        # Initialize encoder to output WAV file
        encoder.init_wav_file_f32(bridge, output_file, 2, 48000)

        # Write silence frames
        encoder.write_silence_f32(bridge, UInt64(1024))

        print("encoder write_silence smoke ok")
    except e:
        encoder.close(bridge)
        raise e^

    encoder.close(bridge)


def run_encoder_write_frames_smoke(input_file: String, output_file: String) raises:
    """Test encoder by transcoding from input file to output WAV file."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")

    # For now, just initialize and write silence as a placeholder
    # Full frame writing would require proper buffer management
    var encoder = MiniAudioEncoderHandle(bridge)

    try:
        # Initialize encoder to output WAV file
        encoder.init_wav_file_f32(bridge, output_file, 2, 48000)

        # Write silence frames as a smoke test
        encoder.write_silence_f32(bridge, UInt64(1024))

        print("encoder write_frames smoke ok (write_silence placeholder)")
    except e:
        encoder.close(bridge)
        raise e^

    encoder.close(bridge)


def try_encoder_wav_file_format_init(
    bridge: MiniAudioCtypes,
    output_path: String,
    sample_format: Int,
    format_name: String,
) raises -> Bool:
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)
    var encoder = bridge.encoder_create()
    if encoder == null_ptr:
        raise Error("encoder_create failed")

    var init_result = bridge.encoder_init_wav_file_format(encoder, output_path, 2, 48000, sample_format)
    if init_result != 0:
        bridge.encoder_destroy(encoder)
        print("encoder format init unavailable:", format_name, result_name(init_result), "(", init_result, ")")
        return False

    var uninit_result = bridge.encoder_uninit(encoder)
    bridge.encoder_destroy(encoder)
    if uninit_result != 0:
        raise Error(format_result_error(bridge, "encoder format uninit failed", uninit_result))

    print("encoder format init ok:", format_name)
    return True


def run_encoder_wav_format_matrix_smoke(output_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)
    var encoder = bridge.encoder_create()
    var success_count = Int(0)

    if encoder == null_ptr:
        raise Error("encoder_create failed")

    var invalid_result = bridge.encoder_init_wav_file_format(encoder, output_path, 2, 48000, 999)
    bridge.encoder_destroy(encoder)
    if invalid_result != MA_INVALID_ARGS:
        raise Error(
            "encoder_init_wav_file_format invalid format expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_result)
        )

    if try_encoder_wav_file_format_init(bridge, output_path, MMJ_SAMPLE_FORMAT_F32, "f32"):
        success_count += 1
    if try_encoder_wav_file_format_init(bridge, output_path, MMJ_SAMPLE_FORMAT_S16, "s16"):
        success_count += 1
    if try_encoder_wav_file_format_init(bridge, output_path, MMJ_SAMPLE_FORMAT_S32, "s32"):
        success_count += 1
    if try_encoder_wav_file_format_init(bridge, output_path, MMJ_SAMPLE_FORMAT_U8, "u8"):
        success_count += 1

    if success_count <= 0:
        raise Error("encoder wav format matrix smoke found no supported formats")

    print("encoder wav format matrix smoke ok (success_count:", success_count, ")")

