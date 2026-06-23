from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import MA_ALREADY_IN_USE, MA_DOES_NOT_EXIST, MA_INVALID_ARGS, MA_UNAVAILABLE, result_name
from miniaudio_handles import MiniAudioDeviceHandle
from miniaudio_result_utils import format_result_error

comptime MMJ_DEVICE_KIND_PLAYBACK = Int(1)
comptime MMJ_DEVICE_KIND_CAPTURE = Int(2)
comptime MMJ_DEVICE_KIND_DUPLEX = Int(3)
comptime MMJ_DEVICE_KIND_DUPLEX_LOOPBACK = Int(4)
comptime MMJ_DEVICE_CALLBACK_MODE_SILENCE = Int(0)
comptime MMJ_DEVICE_CALLBACK_MODE_LOOPBACK = Int(1)
comptime MMJ_SAMPLE_FORMAT_U8 = Int(1)
comptime MMJ_SAMPLE_FORMAT_S16 = Int(2)
comptime MMJ_SAMPLE_FORMAT_S24 = Int(3)
comptime MMJ_SAMPLE_FORMAT_S32 = Int(4)
comptime MMJ_SAMPLE_FORMAT_F32 = Int(5)


def is_device_control_skip_code(code: Int) -> Bool:
    return (
        code == MA_DOES_NOT_EXIST
        or code == MA_UNAVAILABLE
        or code == MA_ALREADY_IN_USE
    )


def run_device_control_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var device = MiniAudioDeviceHandle(bridge)

    try:
        device.init_playback_f32(bridge, 48000, 2)

        if device.is_started(bridge):
            raise Error("device should not be started immediately after init")

        var start_result = bridge.device_start(device.raw)
        if start_result != 0:
            if is_device_control_skip_code(start_result):
                device.close(bridge)
                print(format_result_error(bridge, "device control smoke skipped", start_result))
                return

            raise Error(format_result_error(bridge, "device start failed", start_result))

        if not device.is_started(bridge):
            raise Error("device should report started after start")

        var stop_result = bridge.device_stop(device.raw)
        if stop_result != 0:
            raise Error(format_result_error(bridge, "device stop failed", stop_result))

        if device.is_started(bridge):
            raise Error("device should report stopped after stop")
    except e:
        device.close(bridge)
        raise e^

    device.close(bridge)
    print("device control smoke ok (init + start + stop + close)")


def run_device_volume_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))

    var device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")

    var preinit_set = bridge.device_set_master_volume_f32(device, 0.5)
    if preinit_set != MA_INVALID_ARGS:
        bridge.device_destroy(device)
        raise Error(
            "device_set_master_volume_f32 pre-init expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", preinit_set)
        )

    var preinit_get = bridge.device_get_master_volume_milli(device)
    if preinit_get != MA_INVALID_ARGS:
        bridge.device_destroy(device)
        raise Error(
            "device_get_master_volume_milli pre-init expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", preinit_get)
        )

    var init_result = bridge.device_init_playback_f32(device, 48000, 2)
    if init_result != 0:
        bridge.device_destroy(device)
        if is_device_control_skip_code(init_result):
            print(format_result_error(bridge, "device volume smoke skipped", init_result))
            return

        raise Error(format_result_error(bridge, "device init playback failed", init_result))

    var set_result = bridge.device_set_master_volume_f32(device, 0.25)
    if set_result != 0:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error(format_result_error(bridge, "device set volume failed", set_result))

    var volume_milli = bridge.device_get_master_volume_milli(device)
    if volume_milli < 0:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        var code = Int(volume_milli)
        raise Error(format_result_error(bridge, "device get volume failed", code))

    if volume_milli < 100 or volume_milli > 400:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error(
            "device volume out of expected range after set, got milli: "
            + String(volume_milli)
        )

    _ = bridge.device_uninit(device)
    bridge.device_destroy(device)
    print("device volume smoke ok (pre-init checks + set/get)")


def run_device_config_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))

    var device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")

    var preinit_kind = bridge.device_get_kind(device)
    if preinit_kind != MA_INVALID_ARGS:
        bridge.device_destroy(device)
        raise Error(
            "device_get_kind pre-init expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", preinit_kind)
        )

    var invalid_init = bridge.device_init_f32(device, 999, 48000, 2)
    if invalid_init != MA_INVALID_ARGS:
        bridge.device_destroy(device)
        raise Error(
            "device_init_f32 invalid kind expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_init)
        )

    var init_result = bridge.device_init_f32(
        device,
        MMJ_DEVICE_KIND_PLAYBACK,
        48000,
        2,
    )
    if init_result != 0:
        bridge.device_destroy(device)
        if is_device_control_skip_code(init_result):
            print(format_result_error(bridge, "device config smoke skipped", init_result))
            return

        raise Error(format_result_error(bridge, "device init f32 failed", init_result))

    var kind = bridge.device_get_kind(device)
    var sample_rate = bridge.device_get_sample_rate(device)
    var channels = bridge.device_get_channels(device)

    if kind != MMJ_DEVICE_KIND_PLAYBACK:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error("device kind mismatch after init: " + String(kind))

    if sample_rate != 48000:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error("device sample rate mismatch after init: " + String(sample_rate))

    if channels != 2:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error("device channels mismatch after init: " + String(channels))

    _ = bridge.device_uninit(device)
    bridge.device_destroy(device)
    print("device config smoke ok (unified init + config getters)")


def run_device_init_ex_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var device = MiniAudioDeviceHandle(bridge)

    try:
        var init_result = bridge.device_init_playback_ex_f32(
            device.raw,
            48000,
            2,
            256,
            2,
            1,
        )
        if init_result != 0:
            if is_device_control_skip_code(init_result):
                device.close(bridge)
                print(format_result_error(bridge, "device init_ex smoke skipped", init_result))
                return

            raise Error(format_result_error(bridge, "device init_ex failed", init_result))

        device.initialized = True

        var sample_rate = bridge.device_get_sample_rate(device.raw)
        if sample_rate != 48000:
            raise Error("device init_ex sample rate mismatch: " + String(sample_rate))

        var channels = bridge.device_get_channels(device.raw)
        if channels != 2:
            raise Error("device init_ex channels mismatch: " + String(channels))

        var kind = bridge.device_get_kind(device.raw)
        if kind != MMJ_DEVICE_KIND_PLAYBACK:
            raise Error("device init_ex kind mismatch: " + String(kind))
    except e:
        device.close(bridge)
        raise e^

    device.close(bridge)
    print("device init_ex smoke ok (playback ex init + config getters)")


def try_device_playback_format_init(
    bridge: MiniAudioCtypes,
    sample_format: Int,
    format_name: String,
) raises -> Bool:
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")

    var init_result = bridge.device_init_playback_format(device, 48000, 2, sample_format)
    if init_result != 0:
        bridge.device_destroy(device)
        if is_device_control_skip_code(init_result):
            print("device format init skipped:", format_name, result_name(init_result), "(", init_result, ")")
            return False

        print("device format init unavailable:", format_name, result_name(init_result), "(", init_result, ")")
        return False

    var sample_rate = bridge.device_get_sample_rate(device)
    var channels = bridge.device_get_channels(device)
    _ = bridge.device_uninit(device)
    bridge.device_destroy(device)

    if sample_rate != 48000:
        raise Error("device format init sample rate mismatch for " + format_name + ": " + String(sample_rate))

    if channels != 2:
        raise Error("device format init channels mismatch for " + format_name + ": " + String(channels))

    print("device format init ok:", format_name)
    return True


def try_device_capture_format_init(
    bridge: MiniAudioCtypes,
    sample_format: Int,
    format_name: String,
) raises -> Bool:
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")

    var init_result = bridge.device_init_capture_format(device, 48000, 2, sample_format)
    if init_result != 0:
        bridge.device_destroy(device)
        if is_device_control_skip_code(init_result):
            print("device capture format init skipped:", format_name, result_name(init_result), "(", init_result, ")")
            return False

        print("device capture format init unavailable:", format_name, result_name(init_result), "(", init_result, ")")
        return False

    var sample_rate = bridge.device_get_sample_rate(device)
    var channels = bridge.device_get_channels(device)
    _ = bridge.device_uninit(device)
    bridge.device_destroy(device)

    if sample_rate != 48000:
        raise Error("device capture format init sample rate mismatch for " + format_name + ": " + String(sample_rate))

    if channels != 2:
        raise Error("device capture format init channels mismatch for " + format_name + ": " + String(channels))

    print("device capture format init ok:", format_name)
    return True


def try_device_duplex_format_init(
    bridge: MiniAudioCtypes,
    sample_format: Int,
    format_name: String,
) raises -> Bool:
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")

    var init_result = bridge.device_init_duplex_format(device, 48000, 2, sample_format)
    if init_result != 0:
        bridge.device_destroy(device)
        if is_device_control_skip_code(init_result):
            print("device duplex format init skipped:", format_name, result_name(init_result), "(", init_result, ")")
            return False

        print("device duplex format init unavailable:", format_name, result_name(init_result), "(", init_result, ")")
        return False

    var sample_rate = bridge.device_get_sample_rate(device)
    var channels = bridge.device_get_channels(device)
    _ = bridge.device_uninit(device)
    bridge.device_destroy(device)

    if sample_rate != 48000:
        raise Error("device duplex format init sample rate mismatch for " + format_name + ": " + String(sample_rate))

    if channels != 2:
        raise Error("device duplex format init channels mismatch for " + format_name + ": " + String(channels))

    print("device duplex format init ok:", format_name)
    return True


def try_device_duplex_loopback_format_init(
    bridge: MiniAudioCtypes,
    sample_format: Int,
    format_name: String,
) raises -> Bool:
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")

    var init_result = bridge.device_init_duplex_loopback_format(device, 48000, 2, sample_format)
    if init_result != 0:
        bridge.device_destroy(device)
        if is_device_control_skip_code(init_result):
            print("device duplex loopback format init skipped:", format_name, result_name(init_result), "(", init_result, ")")
            return False

        print("device duplex loopback format init unavailable:", format_name, result_name(init_result), "(", init_result, ")")
        return False

    var sample_rate = bridge.device_get_sample_rate(device)
    var channels = bridge.device_get_channels(device)
    _ = bridge.device_uninit(device)
    bridge.device_destroy(device)

    if sample_rate != 48000:
        raise Error("device duplex loopback format init sample rate mismatch for " + format_name + ": " + String(sample_rate))

    if channels != 2:
        raise Error("device duplex loopback format init channels mismatch for " + format_name + ": " + String(channels))

    print("device duplex loopback format init ok:", format_name)
    return True


def run_device_format_matrix_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var device = bridge.device_create()
    var success_count = Int(0)

    if device == null_ptr:
        raise Error("device_create failed")

    var invalid_playback_result = bridge.device_init_playback_format(device, 48000, 2, 999)
    bridge.device_destroy(device)
    if invalid_playback_result != MA_INVALID_ARGS:
        raise Error(
            "device_init_playback_format invalid format expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_playback_result)
        )

    device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")
    var invalid_capture_result = bridge.device_init_capture_format(device, 48000, 2, 999)
    bridge.device_destroy(device)
    if invalid_capture_result != MA_INVALID_ARGS:
        raise Error(
            "device_init_capture_format invalid format expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_capture_result)
        )

    device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")
    var invalid_duplex_result = bridge.device_init_duplex_format(device, 48000, 2, 999)
    bridge.device_destroy(device)
    if invalid_duplex_result != MA_INVALID_ARGS:
        raise Error(
            "device_init_duplex_format invalid format expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_duplex_result)
        )

    device = bridge.device_create()
    if device == null_ptr:
        raise Error("device_create failed")
    var invalid_duplex_loopback_result = bridge.device_init_duplex_loopback_format(device, 48000, 2, 999)
    bridge.device_destroy(device)
    if invalid_duplex_loopback_result != MA_INVALID_ARGS:
        raise Error(
            "device_init_duplex_loopback_format invalid format expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_duplex_loopback_result)
        )

    if try_device_playback_format_init(bridge, MMJ_SAMPLE_FORMAT_F32, "playback_f32"):
        success_count += 1
    if try_device_playback_format_init(bridge, MMJ_SAMPLE_FORMAT_S16, "playback_s16"):
        success_count += 1
    if try_device_playback_format_init(bridge, MMJ_SAMPLE_FORMAT_S32, "playback_s32"):
        success_count += 1
    if try_device_playback_format_init(bridge, MMJ_SAMPLE_FORMAT_U8, "playback_u8"):
        success_count += 1
    if try_device_playback_format_init(bridge, MMJ_SAMPLE_FORMAT_S24, "playback_s24"):
        success_count += 1

    if try_device_capture_format_init(bridge, MMJ_SAMPLE_FORMAT_F32, "capture_f32"):
        success_count += 1
    if try_device_capture_format_init(bridge, MMJ_SAMPLE_FORMAT_S16, "capture_s16"):
        success_count += 1
    if try_device_capture_format_init(bridge, MMJ_SAMPLE_FORMAT_S32, "capture_s32"):
        success_count += 1
    if try_device_capture_format_init(bridge, MMJ_SAMPLE_FORMAT_U8, "capture_u8"):
        success_count += 1
    if try_device_capture_format_init(bridge, MMJ_SAMPLE_FORMAT_S24, "capture_s24"):
        success_count += 1

    if try_device_duplex_format_init(bridge, MMJ_SAMPLE_FORMAT_F32, "duplex_f32"):
        success_count += 1
    if try_device_duplex_format_init(bridge, MMJ_SAMPLE_FORMAT_S16, "duplex_s16"):
        success_count += 1
    if try_device_duplex_format_init(bridge, MMJ_SAMPLE_FORMAT_S32, "duplex_s32"):
        success_count += 1
    if try_device_duplex_format_init(bridge, MMJ_SAMPLE_FORMAT_U8, "duplex_u8"):
        success_count += 1
    if try_device_duplex_format_init(bridge, MMJ_SAMPLE_FORMAT_S24, "duplex_s24"):
        success_count += 1

    if try_device_duplex_loopback_format_init(bridge, MMJ_SAMPLE_FORMAT_F32, "duplex_loopback_f32"):
        success_count += 1
    if try_device_duplex_loopback_format_init(bridge, MMJ_SAMPLE_FORMAT_S16, "duplex_loopback_s16"):
        success_count += 1
    if try_device_duplex_loopback_format_init(bridge, MMJ_SAMPLE_FORMAT_S32, "duplex_loopback_s32"):
        success_count += 1
    if try_device_duplex_loopback_format_init(bridge, MMJ_SAMPLE_FORMAT_U8, "duplex_loopback_u8"):
        success_count += 1
    if try_device_duplex_loopback_format_init(bridge, MMJ_SAMPLE_FORMAT_S24, "duplex_loopback_s24"):
        success_count += 1

    if success_count <= 0:
        raise Error("device format matrix smoke found no supported formats")

    print("device format matrix smoke ok (success_count:", success_count, ")")


def run_device_callback_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var device = bridge.device_create()

    if device == null_ptr:
        raise Error("device_create failed")

    var init_result = bridge.device_init_playback_f32(device, 48000, 2)
    if init_result != 0:
        bridge.device_destroy(device)
        if is_device_control_skip_code(init_result):
            print(format_result_error(bridge, "device callback smoke skipped", init_result))
            return

        raise Error(format_result_error(bridge, "device callback init failed", init_result))

    var invalid_mode_result = bridge.device_set_callback_mode(device, 99)
    if invalid_mode_result != MA_INVALID_ARGS:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error(
            "device_set_callback_mode invalid expected MA_INVALID_ARGS, got: "
            + format_result_error(bridge, "", invalid_mode_result)
        )

    var mode_result = bridge.device_set_callback_mode(device, MMJ_DEVICE_CALLBACK_MODE_SILENCE)
    if mode_result != 0:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error(format_result_error(bridge, "device set callback mode failed", mode_result))

    var mode = bridge.device_get_callback_mode(device)
    if mode != MMJ_DEVICE_CALLBACK_MODE_SILENCE:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error("device callback mode mismatch after set: " + String(mode))

    var reset_result = bridge.device_reset_observed_frames(device)
    if reset_result != 0:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        raise Error(format_result_error(bridge, "device reset observed frames failed", reset_result))

    var start_result = bridge.device_start(device)
    if start_result != 0:
        _ = bridge.device_uninit(device)
        bridge.device_destroy(device)
        if is_device_control_skip_code(start_result):
            print(format_result_error(bridge, "device callback smoke skipped", start_result))
            return
        raise Error(format_result_error(bridge, "device callback start failed", start_result))

    var wait_result = bridge.device_wait_for_observed_frames(device, 256, 1000, 10)
    var stop_result = bridge.device_stop(device)
    var observed_frames = bridge.device_get_observed_frames(device)
    _ = bridge.device_uninit(device)
    bridge.device_destroy(device)

    if wait_result != 0:
        raise Error(format_result_error(bridge, "device callback wait failed", wait_result))

    if stop_result != 0:
        raise Error(format_result_error(bridge, "device callback stop failed", stop_result))

    if observed_frames <= 0:
        raise Error("device callback smoke expected positive observed frames")

    print("device callback smoke ok (restricted callback mode + observed frames)")


def run_device_callback_longrun_smoke(duration_ms: UInt32 = 600000) raises:
    if duration_ms == 0:
        raise Error("device callback longrun duration must be > 0 ms")

    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var device = MiniAudioDeviceHandle(bridge)
    var batch_window_ms = UInt32(5000)
    var remaining_ms = duration_ms
    var elapsed_ms = UInt32(0)
    var batch_index = UInt32(0)
    var cumulative_observed = Int64(0)

    try:
        device.init_playback_f32(bridge, 48000, 2)
        device.set_callback_mode(bridge, MMJ_DEVICE_CALLBACK_MODE_SILENCE)
        device.start(bridge)

        while remaining_ms > 0:
            var current_batch_ms = batch_window_ms
            if remaining_ms < batch_window_ms:
                current_batch_ms = remaining_ms

            device.reset_observed_frames(bridge)

            var min_frames = UInt64(current_batch_ms) * UInt64(48)
            if min_frames < 256:
                min_frames = 256

            var timeout_ms = current_batch_ms + UInt32(2000)
            if timeout_ms < UInt32(1000):
                timeout_ms = UInt32(1000)

            device.wait_for_observed_frames(bridge, min_frames, timeout_ms, UInt32(10))

            var observed = device.get_observed_frames(bridge)
            if observed <= 0:
                raise Error("device callback longrun expected positive observed frames per batch")

            cumulative_observed += observed
            elapsed_ms += current_batch_ms
            remaining_ms -= current_batch_ms
            batch_index += UInt32(1)

            print(
                "device callback longrun batch",
                batch_index,
                "elapsed_ms:",
                elapsed_ms,
                "observed_frames:",
                observed,
                "cumulative_frames:",
                cumulative_observed,
            )

        device.stop(bridge)
    except e:
        device.close(bridge)
        raise e^

    device.close(bridge)
    print("device callback longrun smoke ok")


def run_device_user_callback_smoke(duration_ms: UInt32 = 500) raises:
    """Test user-defined callback functionality"""
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    
    var result = bridge.device_test_callback_smoke(duration_ms)
    
    if result != 0:
        raise Error(format_result_error(bridge, "device user callback smoke failed", result))
    
    print("device user callback smoke ok")