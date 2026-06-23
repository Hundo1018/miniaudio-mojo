from miniaudio_contract_assertions import expect_negative, expect_nonzero
from miniaudio_ctypes import MiniAudioCtypes


def run_mojo_binding_contract_smoke() raises:
    var bridge = MiniAudioCtypes("./build/libminiaudio_mojo.so")
    var null_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=Int(0))

    # Raw bridge contract checks: null/invalid handles should fail deterministically.
    expect_nonzero("context_init_default(null)", bridge.context_init_default(null_ptr))
    expect_nonzero("context_uninit(null)", bridge.context_uninit(null_ptr))
    expect_negative("context_get_playback_device_count(null)", bridge.context_get_playback_device_count(null_ptr))

    expect_nonzero("engine_init_default(null)", bridge.engine_init_default(null_ptr))
    expect_nonzero("engine_uninit(null)", bridge.engine_uninit(null_ptr))

    expect_nonzero("sound_start(null)", bridge.sound_start(null_ptr))
    expect_nonzero("sound_stop(null)", bridge.sound_stop(null_ptr))
    expect_nonzero("sound_pause(null)", bridge.sound_pause(null_ptr))
    expect_nonzero("sound_seek_to_pcm_frame(null)", bridge.sound_seek_to_pcm_frame(null_ptr, UInt64(0)))
    expect_nonzero("sound_set_looping(null)", bridge.sound_set_looping(null_ptr, True))
    expect_nonzero("sound_set_volume_f32(null)", bridge.sound_set_volume_f32(null_ptr, Float32(0.5)))
    expect_negative("sound_get_cursor_in_pcm_frames(null)", bridge.sound_get_cursor_in_pcm_frames(null_ptr))
    expect_negative("sound_get_time_in_milliseconds(null)", bridge.sound_get_time_in_milliseconds(null_ptr))

    expect_nonzero("sound_group_start(null)", bridge.sound_group_start(null_ptr))
    expect_nonzero("sound_group_stop(null)", bridge.sound_group_stop(null_ptr))
    expect_nonzero("sound_group_set_volume_f32(null)", bridge.sound_group_set_volume_f32(null_ptr, Float32(0.5)))
    expect_nonzero("sound_group_set_pan_f32(null)", bridge.sound_group_set_pan_f32(null_ptr, Float32(0.0)))
    expect_nonzero("sound_group_set_pitch_f32(null)", bridge.sound_group_set_pitch_f32(null_ptr, Float32(1.0)))
    expect_nonzero("sound_group_set_spatialization_enabled(null)", bridge.sound_group_set_spatialization_enabled(null_ptr, True))
    expect_nonzero("sound_group_set_position(null)", bridge.sound_group_set_position(null_ptr, Float32(0), Float32(0), Float32(0)))
    expect_nonzero("sound_group_set_rolloff(null)", bridge.sound_group_set_rolloff(null_ptr, Float32(1.0)))
    expect_nonzero("sound_group_set_min_distance(null)", bridge.sound_group_set_min_distance(null_ptr, Float32(0.1)))
    expect_nonzero("sound_group_set_max_distance(null)", bridge.sound_group_set_max_distance(null_ptr, Float32(10.0)))
    expect_nonzero("sound_group_set_fade_in_pcm_frames(null)", bridge.sound_group_set_fade_in_pcm_frames(null_ptr, Float32(0.0), Float32(1.0), UInt64(10)))
    expect_nonzero("sound_group_set_start_time_in_pcm_frames(null)", bridge.sound_group_set_start_time_in_pcm_frames(null_ptr, UInt64(1)))
    expect_negative("sound_group_get_time_in_pcm_frames(null)", bridge.sound_group_get_time_in_pcm_frames(null_ptr))
    expect_nonzero("sound_group_uninit(null)", bridge.sound_group_uninit(null_ptr))

    expect_nonzero("node_attach_output_bus(null)", bridge.node_attach_output_bus(null_ptr, UInt32(0), null_ptr, UInt32(0)))
    expect_nonzero("node_detach_output_bus(null)", bridge.node_detach_output_bus(null_ptr, UInt32(0)))
    expect_nonzero("node_set_output_bus_volume(null)", bridge.node_set_output_bus_volume(null_ptr, UInt32(0), Float32(1.0)))

    expect_nonzero("lpf_node_init(null)", bridge.lpf_node_init(null_ptr, null_ptr, UInt32(2), UInt32(48000), Float32(1000.0), UInt32(2)))
    expect_nonzero("lpf_node_set_cutoff(null)", bridge.lpf_node_set_cutoff(null_ptr, Float32(1000.0)))
    expect_nonzero("lpf_node_uninit(null)", bridge.lpf_node_uninit(null_ptr))
    expect_nonzero("hpf_node_init(null)", bridge.hpf_node_init(null_ptr, null_ptr, UInt32(2), UInt32(48000), Float32(100.0), UInt32(2)))
    expect_nonzero("hpf_node_set_cutoff(null)", bridge.hpf_node_set_cutoff(null_ptr, Float32(100.0)))
    expect_nonzero("hpf_node_uninit(null)", bridge.hpf_node_uninit(null_ptr))
    expect_nonzero("delay_node_init(null)", bridge.delay_node_init(null_ptr, null_ptr, UInt32(2), UInt32(48000), UInt32(100), Float32(0.5)))
    expect_nonzero("delay_node_set_wet(null)", bridge.delay_node_set_wet(null_ptr, Float32(0.5)))
    expect_nonzero("delay_node_uninit(null)", bridge.delay_node_uninit(null_ptr))
    expect_nonzero("splitter_node_init(null)", bridge.splitter_node_init(null_ptr, null_ptr, UInt32(2)))
    expect_nonzero("splitter_node_set_output_bus_volume(null)", bridge.splitter_node_set_output_bus_volume(null_ptr, UInt32(0), Float32(0.5)))
    expect_nonzero("splitter_node_uninit(null)", bridge.splitter_node_uninit(null_ptr))

    expect_nonzero("resource_manager_init_default(null)", bridge.resource_manager_init_default(null_ptr))
    expect_nonzero("resource_manager_uninit(null)", bridge.resource_manager_uninit(null_ptr))
    expect_nonzero(
        "resource_data_source_wait_result(null)",
        bridge.resource_data_source_wait_result(null_ptr, UInt32(1), UInt32(1)),
    )
    expect_nonzero("resource_data_source_init_file(null)", bridge.resource_data_source_init_file(null_ptr, null_ptr, "/tmp/missing.wav", UInt32(0)))
    expect_nonzero("resource_data_source_init_file_w(null)", bridge.resource_data_source_init_file_w(null_ptr, null_ptr, "/tmp/missing.wav", UInt32(0)))
    expect_nonzero("resource_data_source_init_copy(null)", bridge.resource_data_source_init_copy(null_ptr, null_ptr, null_ptr))
    expect_nonzero("resource_data_source_result(null)", bridge.resource_data_source_result(null_ptr))
    expect_negative("resource_data_source_get_length_in_pcm_frames(null)", bridge.resource_data_source_get_length_in_pcm_frames(null_ptr))
    expect_negative("resource_data_source_get_available_frames(null)", bridge.resource_data_source_get_available_frames(null_ptr))
    expect_nonzero("resource_data_source_uninit(null)", bridge.resource_data_source_uninit(null_ptr))
    expect_nonzero("resource_data_source_seek_to_pcm_frame(null)", bridge.resource_data_source_seek_to_pcm_frame(null_ptr, UInt64(0)))
    expect_nonzero("resource_data_source_set_looping(null)", bridge.resource_data_source_set_looping(null_ptr, Int32(1)))
    expect_nonzero("resource_data_source_set_range_in_pcm_frames(null)", bridge.resource_data_source_set_range_in_pcm_frames(null_ptr, UInt64(0), UInt64(1)))
    expect_nonzero("resource_data_source_set_loop_point_in_pcm_frames(null)", bridge.resource_data_source_set_loop_point_in_pcm_frames(null_ptr, UInt64(0), UInt64(1)))
    expect_nonzero("resource_data_source_seek_to_second(null)", bridge.resource_data_source_seek_to_second(null_ptr, Float32(0.0)))

    expect_nonzero("device_start(null)", bridge.device_start(null_ptr))
    expect_nonzero("device_stop(null)", bridge.device_stop(null_ptr))
    expect_nonzero("device_init_playback_f32(null)", bridge.device_init_playback_f32(null_ptr, UInt32(48000), UInt32(2)))
    expect_nonzero("device_init_capture_f32(null)", bridge.device_init_capture_f32(null_ptr, UInt32(48000), UInt32(2)))
    expect_nonzero("device_init_duplex_f32(null)", bridge.device_init_duplex_f32(null_ptr, UInt32(48000), UInt32(2)))
    expect_nonzero(
        "device_init_capture_ex_f32(null)",
        bridge.device_init_capture_ex_f32(null_ptr, UInt32(48000), UInt32(2), UInt32(128), UInt32(2), 1),
    )
    expect_nonzero(
        "device_init_duplex_ex_f32(null)",
        bridge.device_init_duplex_ex_f32(null_ptr, UInt32(48000), UInt32(2), UInt32(128), UInt32(2), 1),
    )
    expect_nonzero("device_init_f32(null)", bridge.device_init_f32(null_ptr, 0, UInt32(48000), UInt32(2)))
    expect_nonzero("device_set_callback_mode(null)", bridge.device_set_callback_mode(null_ptr, 0))
    expect_nonzero("device_wait_for_observed_frames(null)", bridge.device_wait_for_observed_frames(null_ptr, UInt64(1), UInt32(1), UInt32(1)))
    expect_nonzero("device_set_master_volume_f32(null)", bridge.device_set_master_volume_f32(null_ptr, Float32(0.2)))
    expect_nonzero("device_uninit(null)", bridge.device_uninit(null_ptr))
    expect_nonzero("device_set_data_callback(null)", bridge.device_set_data_callback(null_ptr, null_ptr, null_ptr))
    expect_nonzero("device_set_stop_callback(null)", bridge.device_set_stop_callback(null_ptr, null_ptr, null_ptr))
    expect_nonzero("device_clear_callbacks(null)", bridge.device_clear_callbacks(null_ptr))

    expect_nonzero("decoder_seek_to_pcm_frame(null)", bridge.decoder_seek_to_pcm_frame(null_ptr, UInt64(0)))
    expect_nonzero("decoder_init_file_f32(null)", bridge.decoder_init_file_f32(null_ptr, "/tmp/missing.wav", UInt32(2), UInt32(48000)))
    expect_nonzero("decoder_init_file_vfs_f32(null)", bridge.decoder_init_file_vfs_f32(null_ptr, "/tmp/missing.wav", UInt32(2), UInt32(48000)))
    expect_nonzero("decoder_init_memory_f32(null)", bridge.decoder_init_memory_f32(null_ptr, "", UInt64(0), UInt32(2), UInt32(48000)))
    expect_negative("decoder_read_probe_f32(null)", bridge.decoder_read_probe_f32(null_ptr, UInt64(1)))
    expect_nonzero("decoder_uninit(null)", bridge.decoder_uninit(null_ptr))

    expect_nonzero("encoder_uninit(null)", bridge.encoder_uninit(null_ptr))
    expect_nonzero("encoder_init_wav_file_f32(null)", bridge.encoder_init_wav_file_f32(null_ptr, "/tmp/out.wav", UInt32(2), UInt32(48000)))
    expect_nonzero("encoder_write_silence_f32(null)", bridge.encoder_write_silence_f32(null_ptr, UInt64(1)))
    expect_negative("encoder_write_pcm_frames_f32(null)", bridge.encoder_write_pcm_frames_f32(null_ptr, null_ptr, UInt64(1)))

    expect_nonzero("job_queue_post_custom(null)", bridge.job_queue_post_custom(null_ptr, UInt64(1), UInt64(2)))
    expect_nonzero("job_queue_init(null)", bridge.job_queue_init(null_ptr, UInt32(0), UInt32(4)))
    expect_nonzero("job_queue_post_quit(null)", bridge.job_queue_post_quit(null_ptr))
    expect_negative("job_queue_next_code(null)", bridge.job_queue_next_code(null_ptr))
    expect_nonzero("job_queue_uninit(null)", bridge.job_queue_uninit(null_ptr))

    expect_nonzero("async_notification_poll_init(null)", bridge.async_notification_poll_init(null_ptr))
    expect_nonzero("async_notification_poll_signal(null)", bridge.async_notification_poll_signal(null_ptr))
    expect_nonzero("async_notification_poll_uninit(null)", bridge.async_notification_poll_uninit(null_ptr))

    expect_nonzero("async_notification_event_wait(null)", bridge.async_notification_event_wait(null_ptr))
    expect_nonzero("async_notification_event_init(null)", bridge.async_notification_event_init(null_ptr))
    expect_nonzero("async_notification_event_signal(null)", bridge.async_notification_event_signal(null_ptr))
    expect_nonzero("async_notification_event_uninit(null)", bridge.async_notification_event_uninit(null_ptr))

    expect_nonzero("fence_init(null)", bridge.fence_init(null_ptr))
    expect_nonzero("fence_wait(null)", bridge.fence_wait(null_ptr))
    expect_nonzero("fence_uninit(null)", bridge.fence_uninit(null_ptr))
    expect_nonzero("mutex_init(null)", bridge.mutex_init(null_ptr))
    expect_nonzero("mutex_lock(null)", bridge.mutex_lock(null_ptr))
    expect_nonzero("mutex_unlock(null)", bridge.mutex_unlock(null_ptr))
    expect_nonzero("mutex_uninit(null)", bridge.mutex_uninit(null_ptr))
    expect_nonzero("event_init(null)", bridge.event_init(null_ptr))
    expect_nonzero("event_signal(null)", bridge.event_signal(null_ptr))
    expect_nonzero("event_wait(null)", bridge.event_wait(null_ptr))
    expect_nonzero("event_uninit(null)", bridge.event_uninit(null_ptr))
    expect_nonzero("semaphore_init(null)", bridge.semaphore_init(null_ptr, UInt32(1)))
    expect_nonzero("semaphore_release(null)", bridge.semaphore_release(null_ptr))
    expect_nonzero("semaphore_wait(null)", bridge.semaphore_wait(null_ptr))
    expect_nonzero("semaphore_uninit(null)", bridge.semaphore_uninit(null_ptr))
    expect_nonzero("spinlock_init(null)", bridge.spinlock_init(null_ptr))
    expect_nonzero("spinlock_lock(null)", bridge.spinlock_lock(null_ptr))
    expect_nonzero("spinlock_unlock(null)", bridge.spinlock_unlock(null_ptr))
    expect_nonzero("spinlock_uninit(null)", bridge.spinlock_uninit(null_ptr))

    expect_nonzero("log_init(null)", bridge.log_init(null_ptr))
    expect_nonzero("log_post_info(null)", bridge.log_post_info(null_ptr, "binding-contract"))

    expect_nonzero("custom_buffer_data_source_seek_to_pcm_frame(null)", bridge.custom_buffer_data_source_seek_to_pcm_frame(null_ptr, UInt64(0)))
    expect_negative("custom_buffer_data_source_get_cursor_in_pcm_frames(null)", bridge.custom_buffer_data_source_get_cursor_in_pcm_frames(null_ptr))
    expect_negative("custom_buffer_data_source_get_length_in_pcm_frames(null)", bridge.custom_buffer_data_source_get_length_in_pcm_frames(null_ptr))
    expect_nonzero("custom_buffer_data_source_set_looping(null)", bridge.custom_buffer_data_source_set_looping(null_ptr, Int32(1)))
    expect_nonzero("custom_buffer_data_source_uninit(null)", bridge.custom_buffer_data_source_uninit(null_ptr))

    print("mojo binding contract smoke ok")
