from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioDecoderHandle
from miniaudio_result_utils import format_result_error


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