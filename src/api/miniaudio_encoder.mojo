from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioEncoderHandle
from miniaudio_result_utils import format_result_error


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

