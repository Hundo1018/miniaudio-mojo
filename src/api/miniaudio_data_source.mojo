from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioResourceDataSourceHandle, MiniAudioResourceManagerHandle
from miniaudio_errors import MA_INVALID_ARGS


def run_data_source_extended_smoke(file_path: String) raises:
    """Positive-path smoke: seek / cursor / length / format / channels / samplerate / looping."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        data_source.init_file(bridge, resource_manager, file_path)

        # length
        var length_frames = data_source.get_length_in_pcm_frames(bridge)
        if length_frames <= 0:
            raise Error(
                "data source extended smoke: expected positive length_in_pcm_frames, got: "
                + String(length_frames)
            )
        var length_secs = data_source.get_length_in_seconds(bridge)
        if length_secs <= 0.0:
            raise Error(
                "data source extended smoke: expected positive length_in_seconds, got: "
                + String(length_secs)
            )

        # format / channels / sample rate
        var fmt = data_source.get_format(bridge)
        if fmt <= 0:
            raise Error(
                "data source extended smoke: expected valid format (>0), got: "
                + String(fmt)
            )
        var channels = data_source.get_channels(bridge)
        if channels <= 0:
            raise Error(
                "data source extended smoke: expected positive channel count, got: "
                + String(channels)
            )
        var sample_rate = data_source.get_sample_rate(bridge)
        if sample_rate <= 0:
            raise Error(
                "data source extended smoke: expected positive sample rate, got: "
                + String(sample_rate)
            )

        # seek to 0, verify cursor
        data_source.seek_to_pcm_frame(bridge, 0)
        var cursor0 = data_source.get_cursor_in_pcm_frames(bridge)
        if cursor0 != 0:
            raise Error(
                "data source extended smoke: expected cursor 0 after seek_to_pcm_frame(0), got: "
                + String(cursor0)
            )

        # forward seek
        data_source.seek_pcm_frames(bridge, 100)
        var cursor1 = data_source.get_cursor_in_pcm_frames(bridge)
        if cursor1 != 100:
            raise Error(
                "data source extended smoke: expected cursor 100 after seek_pcm_frames(100), got: "
                + String(cursor1)
            )

        # cursor in seconds should be >= 0
        var cursor_secs = data_source.get_cursor_in_seconds(bridge)
        if cursor_secs < 0.0:
            raise Error(
                "data source extended smoke: expected non-negative cursor_in_seconds, got: "
                + String(cursor_secs)
            )

        # looping toggle
        data_source.set_looping(bridge, True)
        var looping_on = data_source.is_looping(bridge)
        if not looping_on:
            raise Error("data source extended smoke: expected is_looping=true after set_looping(true)")

        data_source.set_looping(bridge, False)
        var looping_off = data_source.is_looping(bridge)
        if looping_off:
            raise Error("data source extended smoke: expected is_looping=false after set_looping(false)")

    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)

    print("data source extended smoke ok")


def run_data_source_range_smoke(file_path: String) raises:
    """Positive-path smoke: set_range / get_range_beg / get_range_end."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        data_source.init_file(bridge, resource_manager, file_path)

        var length_frames = data_source.get_length_in_pcm_frames(bridge)
        var half = UInt64(length_frames // 2)

        data_source.set_range_in_pcm_frames(bridge, 0, half)

        var beg = data_source.get_range_beg_in_pcm_frames(bridge)
        if beg != 0:
            raise Error(
                "data source range smoke: expected range beg=0, got: " + String(beg)
            )
        var end = data_source.get_range_end_in_pcm_frames(bridge)
        if end != Int64(half):
            raise Error(
                "data source range smoke: expected range end="
                + String(Int64(half))
                + ", got: "
                + String(end)
            )

    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)

    print("data source range smoke ok")


def run_data_source_invalid_smoke() raises:
    """Negative-path smoke: all extended ops on uninit data source return MA_INVALID_ARGS / sentinel."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    # seek_to_pcm_frame
    var seek_result = bridge.resource_data_source_seek_to_pcm_frame(data_source.raw, 0)
    if seek_result != MA_INVALID_ARGS:
        data_source.close(bridge)
        raise Error(
            "data source invalid smoke: expected MA_INVALID_ARGS for seek_to_pcm_frame, got: "
            + String(seek_result)
        )

    # seek_pcm_frames
    var fseek_result = bridge.resource_data_source_seek_pcm_frames(data_source.raw, 100)
    if fseek_result != MA_INVALID_ARGS:
        data_source.close(bridge)
        raise Error(
            "data source invalid smoke: expected MA_INVALID_ARGS for seek_pcm_frames, got: "
            + String(fseek_result)
        )

    # get_cursor_in_pcm_frames returns int64 sentinel < 0
    var cursor = bridge.resource_data_source_get_cursor_in_pcm_frames(data_source.raw)
    if cursor >= 0:
        data_source.close(bridge)
        raise Error(
            "data source invalid smoke: expected negative sentinel from get_cursor_in_pcm_frames, got: "
            + String(cursor)
        )

    # get_format
    var fmt = bridge.resource_data_source_get_format(data_source.raw)
    if fmt != MA_INVALID_ARGS:
        data_source.close(bridge)
        raise Error(
            "data source invalid smoke: expected MA_INVALID_ARGS from get_format, got: "
            + String(fmt)
        )

    # set_looping
    var loop_result = bridge.resource_data_source_set_looping(data_source.raw, 1)
    if loop_result != MA_INVALID_ARGS:
        data_source.close(bridge)
        raise Error(
            "data source invalid smoke: expected MA_INVALID_ARGS for set_looping, got: "
            + String(loop_result)
        )

    # set_range_in_pcm_frames
    var range_result = bridge.resource_data_source_set_range_in_pcm_frames(data_source.raw, 0, 100)
    if range_result != MA_INVALID_ARGS:
        data_source.close(bridge)
        raise Error(
            "data source invalid smoke: expected MA_INVALID_ARGS for set_range_in_pcm_frames, got: "
            + String(range_result)
        )

    data_source.close(bridge)
    print("data source invalid smoke ok")


def run_data_source_loop_point_smoke(file_path: String) raises:
    """Positive-path smoke: set_loop_point / get_loop_point / seek_to_second / seek_seconds."""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        data_source.init_file(bridge, resource_manager, file_path)

        var length_frames = data_source.get_length_in_pcm_frames(bridge)
        var quarter = UInt64(length_frames // 4)
        var three_quarter = UInt64(3 * length_frames // 4)

        # set loop point
        data_source.set_loop_point_in_pcm_frames(bridge, quarter, three_quarter)

        var lp_beg = data_source.get_loop_point_beg_in_pcm_frames(bridge)
        if lp_beg != Int64(quarter):
            raise Error(
                "data source loop point smoke: expected loop beg="
                + String(Int64(quarter))
                + ", got: "
                + String(lp_beg)
            )
        var lp_end = data_source.get_loop_point_end_in_pcm_frames(bridge)
        if lp_end != Int64(three_quarter):
            raise Error(
                "data source loop point smoke: expected loop end="
                + String(Int64(three_quarter))
                + ", got: "
                + String(lp_end)
            )

        # seek_to_second: seek to 0.0 and verify cursor at 0
        data_source.seek_to_second(bridge, 0.0)
        var cursor_after_seek = data_source.get_cursor_in_pcm_frames(bridge)
        if cursor_after_seek != 0:
            raise Error(
                "data source loop point smoke: expected cursor=0 after seek_to_second(0.0), got: "
                + String(cursor_after_seek)
            )

        # seek_seconds: forward by a small amount, cursor must advance
        data_source.seek_seconds(bridge, 0.01)
        var cursor_after_fwd = data_source.get_cursor_in_pcm_frames(bridge)
        if cursor_after_fwd <= 0:
            raise Error(
                "data source loop point smoke: expected cursor > 0 after seek_seconds(0.01), got: "
                + String(cursor_after_fwd)
            )

    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)

    print("data source loop point smoke ok")
