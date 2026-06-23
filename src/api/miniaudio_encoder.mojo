from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import MA_INVALID_ARGS, result_name
from miniaudio_handles import MiniAudioDecoderHandle, MiniAudioEncoderHandle
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
    var decoder = MiniAudioDecoderHandle(bridge)
    var encoder = MiniAudioEncoderHandle(bridge)
    var chunk_frames = UInt64(1024)
    var channel_count = UInt64(2)
    var sample_size_bytes = UInt64(4)
    var pcm_buffer = String(" ") * Int(chunk_frames * channel_count * sample_size_bytes)
    var total_frames_written = UInt64(0)

    try:
        decoder.init_file_f32(bridge, input_file, 2, 48000)
        encoder.init_wav_file_f32(bridge, output_file, 2, 48000)

        while True:
            var frames_read = decoder.read_frames_f32_count(bridge, pcm_buffer, chunk_frames)
            if frames_read == 0:
                break

            var frames_written = encoder.write_pcm_frames_f32_buffer(
                bridge,
                pcm_buffer,
                frames_read,
            )
            if frames_written != frames_read:
                raise Error(
                    "encoder write_frames smoke short write: expected "
                    + String(frames_read)
                    + ", got: "
                    + String(frames_written)
                )

            total_frames_written += frames_written

        if total_frames_written == 0:
            raise Error("encoder write_frames smoke wrote 0 frames")

    except e:
        decoder.close(bridge)
        encoder.close(bridge)
        raise e^

    decoder.close(bridge)
    encoder.close(bridge)

    var output_decoder = MiniAudioDecoderHandle(bridge)
    try:
        output_decoder.init_file_f32(bridge, output_file, 2, 48000)
        var probe_read = output_decoder.read_probe_f32(bridge, 64)
        if probe_read <= 0:
            raise Error("encoder write_frames smoke output probe read 0 frames")
    except e:
        output_decoder.close(bridge)
        raise e^

    output_decoder.close(bridge)
    print("encoder write_frames smoke ok (transcoded frames:", total_frames_written, ")")


def run_encoder_invalid_state_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var decoder = MiniAudioDecoderHandle(bridge)
    var encoder = MiniAudioEncoderHandle(bridge)
    var caught = Int(0)
    var pcm_buffer = String(" ") * Int(2 * 2 * 4)

    try:
        encoder.write_silence_f32(bridge, UInt64(1))
        raise Error("encoder invalid-state smoke expected write_silence_f32 to fail")
    except _:
        caught += 1

    try:
        _ = encoder.write_pcm_frames_f32_buffer(bridge, pcm_buffer, UInt64(1))
        raise Error("encoder invalid-state smoke expected write_pcm_frames_f32_buffer to fail")
    except _:
        caught += 1

    try:
        _ = decoder.read_probe_f32(bridge, UInt64(1))
        raise Error("encoder invalid-state smoke expected decoder read_probe_f32 to fail")
    except _:
        caught += 1

    try:
        _ = decoder.read_frames_f32_count(bridge, pcm_buffer, UInt64(1))
        raise Error("encoder invalid-state smoke expected decoder read_frames_f32_count to fail")
    except _:
        caught += 1

    decoder.close(bridge)
    encoder.close(bridge)

    if caught != 4:
        raise Error("encoder invalid-state smoke failed to validate all guardrails")

    print("encoder invalid-state smoke ok")


def try_encoder_wav_file_format_init(
    bridge: MiniAudioCtypes,
    output_path: String,
    sample_format: Int,
    format_name: String,
) raises -> Bool:
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
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
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
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


def run_encoder_vfs_wav_smoke(output_file: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var encoder = MiniAudioEncoderHandle(bridge)
    var decoder = MiniAudioDecoderHandle(bridge)

    try:
        encoder.init_wav_file_vfs_f32(bridge, output_file, 2, 48000)
        encoder.write_silence_f32(bridge, UInt64(256))
    except e:
        encoder.close(bridge)
        decoder.close(bridge)
        raise e^

    encoder.close(bridge)

    try:
        decoder.init_file_f32(bridge, output_file, 2, 48000)
        var probe_read = decoder.read_probe_f32(bridge, 64)
        if probe_read <= 0:
            raise Error("encoder VFS WAV smoke output probe read 0 frames")
    except e:
        decoder.close(bridge)
        raise e^

    decoder.close(bridge)
    print("encoder VFS WAV smoke ok (init_vfs + write + decode verify)")

