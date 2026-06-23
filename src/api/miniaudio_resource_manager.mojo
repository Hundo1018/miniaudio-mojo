from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioAsyncNotificationPollHandle, MiniAudioFenceHandle, MiniAudioResourceDataSourceHandle, MiniAudioResourceManagerHandle
from miniaudio_errors import MA_BUSY, MA_SUCCESS
from miniaudio_result_utils import format_result_error


def run_resource_manager_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        data_source.init_file(bridge, resource_manager, file_path)
        var length = data_source.get_length_in_pcm_frames(bridge)
        if length <= 0:
            raise Error("resource data source length must be > 0")
        print("resource manager data source length:", length)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)

    print("resource manager smoke ok")


def run_resource_manager_async_poll_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        data_source.init_file_async(bridge, resource_manager, file_path)

        var result_code = data_source.wait_result_code(bridge, 2000, 50)
        print("resource manager async final result code:", result_code)

        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager async data source failed",
                    result_code,
                )
            )

        var length = data_source.get_length_in_pcm_frames(bridge)
        if length <= 0:
            raise Error("resource manager async data source length must be > 0")
        print("resource manager async data source length:", length)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)

    print("resource manager async poll smoke ok")


def run_resource_manager_streaming_async_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        data_source.init_file_stream_async(bridge, resource_manager, file_path)

        var initial_result_code = data_source.result_code(bridge)
        print("resource manager streaming async initial result code:", initial_result_code)

        if initial_result_code != MA_BUSY and initial_result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager streaming async initial state failed",
                    initial_result_code,
                )
            )

        var final_result_code = data_source.wait_result_code(bridge, 2000, 50)
        print("resource manager streaming async final result code:", final_result_code)

        if final_result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager streaming async data source failed",
                    final_result_code,
                )
            )

        var available_frames = data_source.get_available_frames(bridge)
        if available_frames <= 0:
            raise Error("resource manager streaming async available frames must be > 0")
        print("resource manager streaming async available frames:", available_frames)

        var length = data_source.get_length_in_pcm_frames(bridge)
        if length <= 0:
            raise Error("resource manager streaming async data source length must be > 0")
        print("resource manager streaming async data source length:", length)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)

    print("resource manager streaming async smoke ok")


def run_resource_manager_init_ex_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        data_source.init_ex(
            bridge,
            resource_manager,
            file_path,
            bridge.resource_data_source_flag_async()
            | bridge.resource_data_source_flag_stream()
            | bridge.resource_data_source_flag_decode()
            | bridge.resource_data_source_flag_wait_init(),
            32,
            0,
            128,
            16,
            96,
            True,
        )

        var result_code = data_source.result_code(bridge)
        print("resource manager init_ex result code:", result_code)
        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager init_ex data source failed",
                    result_code,
                )
            )

        var cursor = data_source.get_cursor_in_pcm_frames(bridge)
        if cursor != 32:
            raise Error("resource manager init_ex cursor mismatch: " + String(cursor))

        var range_beg = data_source.get_range_beg_in_pcm_frames(bridge)
        if range_beg != 0:
            raise Error("resource manager init_ex range begin mismatch: " + String(range_beg))

        var range_end = data_source.get_range_end_in_pcm_frames(bridge)
        if range_end != 128:
            raise Error("resource manager init_ex range end mismatch: " + String(range_end))

        var loop_beg = data_source.get_loop_point_beg_in_pcm_frames(bridge)
        if loop_beg != 16:
            raise Error("resource manager init_ex loop begin mismatch: " + String(loop_beg))

        var loop_end = data_source.get_loop_point_end_in_pcm_frames(bridge)
        if loop_end != 96:
            raise Error("resource manager init_ex loop end mismatch: " + String(loop_end))

        if not data_source.is_looping(bridge):
            raise Error("resource manager init_ex expected looping enabled")

        var available_frames = data_source.get_available_frames(bridge)
        if available_frames <= 0:
            raise Error("resource manager init_ex available frames must be > 0")

        print("resource manager init_ex available frames:", available_frames)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)

    print("resource manager init_ex smoke ok")


def run_resource_manager_init_ex_w_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        data_source.init_ex_w(
            bridge,
            resource_manager,
            file_path,
            bridge.resource_data_source_flag_async()
            | bridge.resource_data_source_flag_stream()
            | bridge.resource_data_source_flag_decode()
            | bridge.resource_data_source_flag_wait_init(),
            32,
            0,
            128,
            16,
            96,
            True,
        )

        var result_code = data_source.result_code(bridge)
        print("resource manager init_ex_w result code:", result_code)
        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager init_ex_w data source failed",
                    result_code,
                )
            )

        var cursor = data_source.get_cursor_in_pcm_frames(bridge)
        if cursor != 32:
            raise Error("resource manager init_ex_w cursor mismatch: " + String(cursor))

        var range_beg = data_source.get_range_beg_in_pcm_frames(bridge)
        if range_beg != 0:
            raise Error("resource manager init_ex_w range begin mismatch: " + String(range_beg))

        var range_end = data_source.get_range_end_in_pcm_frames(bridge)
        if range_end != 128:
            raise Error("resource manager init_ex_w range end mismatch: " + String(range_end))

        var loop_beg = data_source.get_loop_point_beg_in_pcm_frames(bridge)
        if loop_beg != 16:
            raise Error("resource manager init_ex_w loop begin mismatch: " + String(loop_beg))

        var loop_end = data_source.get_loop_point_end_in_pcm_frames(bridge)
        if loop_end != 96:
            raise Error("resource manager init_ex_w loop end mismatch: " + String(loop_end))

        if not data_source.is_looping(bridge):
            raise Error("resource manager init_ex_w expected looping enabled")

        var available_frames = data_source.get_available_frames(bridge)
        if available_frames <= 0:
            raise Error("resource manager init_ex_w available frames must be > 0")

        print("resource manager init_ex_w available frames:", available_frames)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)

    print("resource manager init_ex_w smoke ok")


def run_resource_manager_init_copy_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var source_a = MiniAudioResourceDataSourceHandle(bridge)
    var source_b = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        source_a.init_file(bridge, resource_manager, file_path)

        source_b.init_copy(bridge, resource_manager, source_a)

        var result_code = source_b.result_code(bridge)
        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager init_copy destination source failed",
                    result_code,
                )
            )

        var length_a = source_a.get_length_in_pcm_frames(bridge)
        var length_b = source_b.get_length_in_pcm_frames(bridge)
        if length_a <= 0 or length_b <= 0:
            raise Error("resource manager init_copy length must be > 0")
        if length_a != length_b:
            raise Error(
                "resource manager init_copy length mismatch: "
                + String(length_a)
                + " vs "
                + String(length_b)
            )

        var format_a = source_a.get_format(bridge)
        var format_b = source_b.get_format(bridge)
        if format_a != format_b:
            raise Error(
                "resource manager init_copy format mismatch: "
                + String(format_a)
                + " vs "
                + String(format_b)
            )

        var channels_a = source_a.get_channels(bridge)
        var channels_b = source_b.get_channels(bridge)
        if channels_a != channels_b:
            raise Error(
                "resource manager init_copy channels mismatch: "
                + String(channels_a)
                + " vs "
                + String(channels_b)
            )

        var sample_rate_a = source_a.get_sample_rate(bridge)
        var sample_rate_b = source_b.get_sample_rate(bridge)
        if sample_rate_a != sample_rate_b:
            raise Error(
                "resource manager init_copy sample rate mismatch: "
                + String(sample_rate_a)
                + " vs "
                + String(sample_rate_b)
            )

        print("resource manager init_copy length:", length_b)
    finally:
        source_b.close(bridge)
        source_a.close(bridge)
        resource_manager.close(bridge)

    print("resource manager init_copy smoke ok")


def run_resource_manager_init_w_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)

    try:
        resource_manager.init_default(bridge)
        data_source.init_file_w(bridge, resource_manager, file_path)

        var result_code = data_source.result_code(bridge)
        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager init_w data source failed",
                    result_code,
                )
            )

        var length = data_source.get_length_in_pcm_frames(bridge)
        if length <= 0:
            raise Error("resource manager init_w data source length must be > 0")

        print("resource manager init_w data source length:", length)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)

    print("resource manager init_w smoke ok")


def run_resource_manager_pipeline_notification_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)
    var init_notification = MiniAudioAsyncNotificationPollHandle(bridge)
    var done_notification = MiniAudioAsyncNotificationPollHandle(bridge)

    try:
        init_notification.init(bridge)
        done_notification.init(bridge)
        resource_manager.init_default(bridge)

        data_source.init_file_async_with_poll_notifications(
            bridge,
            resource_manager,
            file_path,
            init_notification,
            done_notification,
        )

        var result_code = data_source.wait_result_code(bridge, 2000, 50)
        print("resource manager pipeline notifications final result code:", result_code)

        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager pipeline notifications data source failed",
                    result_code,
                )
            )

        if not init_notification.is_signalled(bridge):
            raise Error("resource manager pipeline notifications init stage was not signalled")

        if not done_notification.is_signalled(bridge):
            raise Error("resource manager pipeline notifications done stage was not signalled")

        var length = data_source.get_length_in_pcm_frames(bridge)
        if length <= 0:
            raise Error("resource manager pipeline notifications data source length must be > 0")

        print("resource manager pipeline notifications data source length:", length)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)
        init_notification.close(bridge)
        done_notification.close(bridge)

    print("resource manager pipeline notifications smoke ok")


def run_resource_manager_pipeline_notification_w_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)
    var init_notification = MiniAudioAsyncNotificationPollHandle(bridge)
    var done_notification = MiniAudioAsyncNotificationPollHandle(bridge)

    try:
        init_notification.init(bridge)
        done_notification.init(bridge)
        resource_manager.init_default(bridge)

        data_source.init_file_w_async_with_poll_notifications(
            bridge,
            resource_manager,
            file_path,
            init_notification,
            done_notification,
        )

        var result_code = data_source.wait_result_code(bridge, 2000, 50)
        print("resource manager pipeline notifications_w final result code:", result_code)

        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager pipeline notifications_w data source failed",
                    result_code,
                )
            )

        if not init_notification.is_signalled(bridge):
            raise Error("resource manager pipeline notifications_w init stage was not signalled")

        if not done_notification.is_signalled(bridge):
            raise Error("resource manager pipeline notifications_w done stage was not signalled")

        var length = data_source.get_length_in_pcm_frames(bridge)
        if length <= 0:
            raise Error("resource manager pipeline notifications_w data source length must be > 0")

        print("resource manager pipeline notifications_w data source length:", length)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)
        init_notification.close(bridge)
        done_notification.close(bridge)

    print("resource manager pipeline notifications_w smoke ok")


def run_resource_manager_pipeline_fence_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)
    var init_fence = MiniAudioFenceHandle(bridge)
    var done_fence = MiniAudioFenceHandle(bridge)

    try:
        init_fence.init(bridge)
        done_fence.init(bridge)
        resource_manager.init_default(bridge)

        data_source.init_file_async_with_fences(
            bridge,
            resource_manager,
            file_path,
            init_fence,
            done_fence,
        )

        init_fence.wait(bridge)
        done_fence.wait(bridge)

        var result_code = data_source.wait_result_code(bridge, 2000, 50)
        print("resource manager pipeline fences final result code:", result_code)

        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager pipeline fences data source failed",
                    result_code,
                )
            )

        var length = data_source.get_length_in_pcm_frames(bridge)
        if length <= 0:
            raise Error("resource manager pipeline fences data source length must be > 0")

        print("resource manager pipeline fences data source length:", length)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)
        init_fence.close(bridge)
        done_fence.close(bridge)

    print("resource manager pipeline fences smoke ok")


def run_resource_manager_pipeline_notifications_and_fences_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)
    var init_notification = MiniAudioAsyncNotificationPollHandle(bridge)
    var done_notification = MiniAudioAsyncNotificationPollHandle(bridge)
    var init_fence = MiniAudioFenceHandle(bridge)
    var done_fence = MiniAudioFenceHandle(bridge)

    try:
        init_notification.init(bridge)
        done_notification.init(bridge)
        init_fence.init(bridge)
        done_fence.init(bridge)
        resource_manager.init_default(bridge)

        data_source.init_file_async_with_poll_notifications_and_fences(
            bridge,
            resource_manager,
            file_path,
            init_notification,
            done_notification,
            init_fence,
            done_fence,
        )

        init_fence.wait(bridge)
        done_fence.wait(bridge)

        var result_code = data_source.wait_result_code(bridge, 2000, 50)
        print("resource manager pipeline notifications+fences final result code:", result_code)

        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager pipeline notifications+fences data source failed",
                    result_code,
                )
            )

        if not init_notification.is_signalled(bridge):
            raise Error("resource manager pipeline notifications+fences init stage was not signalled")

        if not done_notification.is_signalled(bridge):
            raise Error("resource manager pipeline notifications+fences done stage was not signalled")

        var length = data_source.get_length_in_pcm_frames(bridge)
        if length <= 0:
            raise Error("resource manager pipeline notifications+fences data source length must be > 0")

        print("resource manager pipeline notifications+fences data source length:", length)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)
        init_notification.close(bridge)
        done_notification.close(bridge)
        init_fence.close(bridge)
        done_fence.close(bridge)

    print("resource manager pipeline notifications+fences smoke ok")


def run_resource_manager_pipeline_notifications_and_fences_w_smoke(file_path: String) raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var resource_manager = MiniAudioResourceManagerHandle(bridge)
    var data_source = MiniAudioResourceDataSourceHandle(bridge)
    var init_notification = MiniAudioAsyncNotificationPollHandle(bridge)
    var done_notification = MiniAudioAsyncNotificationPollHandle(bridge)
    var init_fence = MiniAudioFenceHandle(bridge)
    var done_fence = MiniAudioFenceHandle(bridge)

    try:
        init_notification.init(bridge)
        done_notification.init(bridge)
        init_fence.init(bridge)
        done_fence.init(bridge)
        resource_manager.init_default(bridge)

        data_source.init_file_w_async_with_poll_notifications_and_fences(
            bridge,
            resource_manager,
            file_path,
            init_notification,
            done_notification,
            init_fence,
            done_fence,
        )

        init_fence.wait(bridge)
        done_fence.wait(bridge)

        var result_code = data_source.wait_result_code(bridge, 2000, 50)
        print("resource manager pipeline notifications+fences_w final result code:", result_code)

        if result_code != MA_SUCCESS:
            raise Error(
                format_result_error(
                    bridge,
                    "resource manager pipeline notifications+fences_w data source failed",
                    result_code,
                )
            )

        if not init_notification.is_signalled(bridge):
            raise Error("resource manager pipeline notifications+fences_w init stage was not signalled")

        if not done_notification.is_signalled(bridge):
            raise Error("resource manager pipeline notifications+fences_w done stage was not signalled")

        var length = data_source.get_length_in_pcm_frames(bridge)
        if length <= 0:
            raise Error("resource manager pipeline notifications+fences_w data source length must be > 0")

        print("resource manager pipeline notifications+fences_w data source length:", length)
    finally:
        data_source.close(bridge)
        resource_manager.close(bridge)
        init_notification.close(bridge)
        done_notification.close(bridge)
        init_fence.close(bridge)
        done_fence.close(bridge)

    print("resource manager pipeline notifications+fences_w smoke ok")
