from miniaudio_contract_assertions import expect_equal_int, expect_nonzero, expect_zero
from miniaudio_ctypes import MiniAudioCtypes


def run_mojo_device_init_ex_contract_suite() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))
    var device = bridge.device_create()

    if device == null_ptr:
        raise Error("device_create failed in init_ex contract suite")

    # Deterministic contract checks: these must fail before any backend interaction.
    expect_nonzero(
        "device_init_playback_ex_f32(sample_rate=0)",
        bridge.device_init_playback_ex_f32(device, UInt32(0), UInt32(2), UInt32(128), UInt32(2), 1),
    )
    expect_nonzero(
        "device_init_capture_ex_f32(sample_rate=0)",
        bridge.device_init_capture_ex_f32(device, UInt32(0), UInt32(2), UInt32(128), UInt32(2), 1),
    )
    expect_nonzero(
        "device_init_duplex_ex_f32(sample_rate=0)",
        bridge.device_init_duplex_ex_f32(device, UInt32(0), UInt32(2), UInt32(128), UInt32(2), 1),
    )

    expect_nonzero(
        "device_init_playback_ex_f32(channels=0)",
        bridge.device_init_playback_ex_f32(device, UInt32(48000), UInt32(0), UInt32(128), UInt32(2), 1),
    )
    expect_nonzero(
        "device_init_capture_ex_f32(channels=0)",
        bridge.device_init_capture_ex_f32(device, UInt32(48000), UInt32(0), UInt32(128), UInt32(2), 1),
    )
    expect_nonzero(
        "device_init_duplex_ex_f32(channels=0)",
        bridge.device_init_duplex_ex_f32(device, UInt32(48000), UInt32(0), UInt32(128), UInt32(2), 1),
    )

    expect_nonzero(
        "device_init_playback_ex_f32(period_count=17)",
        bridge.device_init_playback_ex_f32(device, UInt32(48000), UInt32(2), UInt32(128), UInt32(17), 1),
    )
    expect_nonzero(
        "device_init_capture_ex_f32(period_count=17)",
        bridge.device_init_capture_ex_f32(device, UInt32(48000), UInt32(2), UInt32(128), UInt32(17), 1),
    )
    expect_nonzero(
        "device_init_duplex_ex_f32(period_count=17)",
        bridge.device_init_duplex_ex_f32(device, UInt32(48000), UInt32(2), UInt32(128), UInt32(17), 1),
    )

    # Opportunistic positive checks: if backend is available, validate state semantics.
    var playback_result = bridge.device_init_playback_ex_f32(
        device,
        UInt32(48000),
        UInt32(2),
        UInt32(128),
        UInt32(2),
        1,
    )
    if playback_result == 0:
        expect_equal_int("device_get_kind(playback_ex)", bridge.device_get_kind(device), 1)
        expect_equal_int("device_get_sample_rate(playback_ex)", bridge.device_get_sample_rate(device), 48000)
        expect_equal_int("device_get_channels(playback_ex)", bridge.device_get_channels(device), 2)
        expect_equal_int("device_get_callback_mode(playback_ex)", bridge.device_get_callback_mode(device), 0)
        expect_zero("device_uninit(playback_ex)", bridge.device_uninit(device))
        expect_zero("device_uninit(playback_ex, second)", bridge.device_uninit(device))

    var capture_result = bridge.device_init_capture_ex_f32(
        device,
        UInt32(48000),
        UInt32(2),
        UInt32(128),
        UInt32(2),
        1,
    )
    if capture_result == 0:
        expect_equal_int("device_get_kind(capture_ex)", bridge.device_get_kind(device), 2)
        expect_equal_int("device_get_sample_rate(capture_ex)", bridge.device_get_sample_rate(device), 48000)
        expect_equal_int("device_get_channels(capture_ex)", bridge.device_get_channels(device), 2)
        expect_zero("device_uninit(capture_ex)", bridge.device_uninit(device))

    var duplex_result = bridge.device_init_duplex_ex_f32(
        device,
        UInt32(48000),
        UInt32(2),
        UInt32(128),
        UInt32(2),
        0,
    )
    if duplex_result == 0:
        expect_equal_int("device_get_kind(duplex_ex)", bridge.device_get_kind(device), 3)
        expect_equal_int("device_get_sample_rate(duplex_ex)", bridge.device_get_sample_rate(device), 48000)
        expect_equal_int("device_get_channels(duplex_ex)", bridge.device_get_channels(device), 2)
        expect_zero("device_uninit(duplex_ex)", bridge.device_uninit(device))

    # Re-init transition contract: re-using same handle across kinds must remain valid.
    var transition_playback = bridge.device_init_playback_ex_f32(
        device,
        UInt32(48000),
        UInt32(2),
        UInt32(128),
        UInt32(2),
        0,
    )
    if transition_playback == 0:
        var transition_capture = bridge.device_init_capture_ex_f32(
            device,
            UInt32(48000),
            UInt32(2),
            UInt32(128),
            UInt32(2),
            0,
        )
        if transition_capture == 0:
            expect_equal_int("device_get_kind(reinit->capture_ex)", bridge.device_get_kind(device), 2)
            expect_zero("device_uninit(reinit->capture_ex)", bridge.device_uninit(device))
        else:
            expect_zero("device_uninit(reinit playback fallback)", bridge.device_uninit(device))

    bridge.device_destroy(device)
    print("mojo device init_ex contract suite ok")
