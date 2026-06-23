#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "miniaudio_shim.h"

typedef int (*mmj_smoke_fn)(void);

static int run_named_smoke(const char* name, mmj_smoke_fn fn) {
    int result = fn();
    if (result != 0) {
        printf("failed: %s -> %s (%d)\n", name, mmj_result_description(result), result);
        return result;
    }

    printf("ok: %s\n", name);
    return 0;
}

static int expect_nonzero_rc(const char* name, int rc) {
    if (rc == 0) {
        printf("failed: expected non-zero result for %s\n", name);
        return -100;
    }
    return 0;
}

static int expect_negative_i64(const char* name, int64_t value) {
    if (value >= 0) {
        printf("failed: expected negative value for %s (got %lld)\n", name, (long long)value);
        return -101;
    }
    return 0;
}

static int run_logging_smoke_inline(void) {
    void* handle = mmj_log_create();
    int result = 0;
    int64_t callback_count = 0;

    if (handle == NULL) {
        return -1;
    }

    result = mmj_log_init(handle);
    if (result != 0) {
        mmj_log_destroy(handle);
        return result;
    }

    result = mmj_log_register_counting_callback(handle);
    if (result != 0) {
        mmj_log_uninit(handle);
        mmj_log_destroy(handle);
        return result;
    }

    result = mmj_log_post_info(handle, "native logging smoke message");
    if (result != 0) {
        mmj_log_unregister_counting_callback(handle);
        mmj_log_uninit(handle);
        mmj_log_destroy(handle);
        return result;
    }

    callback_count = mmj_log_get_callback_count(handle);
    if (callback_count < 1) {
        mmj_log_unregister_counting_callback(handle);
        mmj_log_uninit(handle);
        mmj_log_destroy(handle);
        return -2;
    }

    result = mmj_log_unregister_counting_callback(handle);
    if (result != 0) {
        mmj_log_uninit(handle);
        mmj_log_destroy(handle);
        return result;
    }

    result = mmj_log_uninit(handle);
    if (result != 0) {
        mmj_log_destroy(handle);
        return result;
    }

    mmj_log_destroy(handle);
    return 0;
}

static int run_device_test_callback_smoke_inline(void) {
    return mmj_device_test_callback_smoke(20);
}

static int run_null_guard_suite(void) {
    int rc;
    int64_t i64;

    rc = expect_nonzero_rc("context_init_default(null)", mmj_context_init_default(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("context_uninit(null)", mmj_context_uninit(NULL));
    if (rc != 0) return rc;
    i64 = mmj_context_get_playback_device_count(NULL);
    rc = expect_negative_i64("context_get_playback_device_count(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_context_get_capture_device_count(NULL);
    rc = expect_negative_i64("context_get_capture_device_count(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("context_get_playback_device_name(null)", mmj_context_get_playback_device_name(NULL, 0, NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("context_get_capture_device_name(null)", mmj_context_get_capture_device_name(NULL, 0, NULL, 0));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("engine_init_default(null)", mmj_engine_init_default(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("engine_uninit(null)", mmj_engine_uninit(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("engine_play_sound(null)", mmj_engine_play_sound(NULL, "./missing.wav"));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("engine_listener_set_position(null)", mmj_engine_listener_set_position(NULL, 0, 0.0f, 0.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("engine_listener_set_direction(null)", mmj_engine_listener_set_direction(NULL, 0, 0.0f, 0.0f, -1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("engine_listener_set_world_up(null)", mmj_engine_listener_set_world_up(NULL, 0, 0.0f, 1.0f, 0.0f));
    if (rc != 0) return rc;
    (void)mmj_engine_get_endpoint(NULL);

    rc = expect_nonzero_rc("sound_start(null)", mmj_sound_start(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_stop(null)", mmj_sound_stop(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_pause(null)", mmj_sound_pause(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_set_looping(null)", mmj_sound_set_looping(NULL, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_init_from_file(null)", mmj_sound_init_from_file(NULL, NULL, "./missing.wav"));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_init_from_file_in_group(null)", mmj_sound_init_from_file_in_group(NULL, NULL, NULL, "./missing.wav"));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_seek_to_pcm_frame(null)", mmj_sound_seek_to_pcm_frame(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_set_volume_f32(null)", mmj_sound_set_volume_f32(NULL, 0.5f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_set_spatialization_enabled(null)", mmj_sound_set_spatialization_enabled(NULL, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_set_position(null)", mmj_sound_set_position(NULL, 0.0f, 0.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_set_rolloff(null)", mmj_sound_set_rolloff(NULL, 1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_set_min_distance(null)", mmj_sound_set_min_distance(NULL, 0.1f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_set_max_distance(null)", mmj_sound_set_max_distance(NULL, 10.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_uninit(null)", mmj_sound_uninit(NULL));
    if (rc != 0) return rc;
    i64 = mmj_sound_get_cursor_in_pcm_frames(NULL);
    rc = expect_negative_i64("sound_get_cursor_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_sound_get_time_in_milliseconds(NULL);
    rc = expect_negative_i64("sound_get_time_in_milliseconds(null)", i64);
    if (rc != 0) return rc;
    (void)mmj_sound_get_node(NULL);
    (void)mmj_sound_is_finished(NULL);

    rc = expect_nonzero_rc("sound_group_start(null)", mmj_sound_group_start(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_stop(null)", mmj_sound_group_stop(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_volume_f32(null)", mmj_sound_group_set_volume_f32(NULL, 0.5f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_init_default(null)", mmj_sound_group_init_default(NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_init_with_parent(null)", mmj_sound_group_init_with_parent(NULL, NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_pan_f32(null)", mmj_sound_group_set_pan_f32(NULL, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_pitch_f32(null)", mmj_sound_group_set_pitch_f32(NULL, 1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_spatialization_enabled(null)", mmj_sound_group_set_spatialization_enabled(NULL, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_position(null)", mmj_sound_group_set_position(NULL, 0.0f, 0.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_direction(null)", mmj_sound_group_set_direction(NULL, 0.0f, 0.0f, -1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_velocity(null)", mmj_sound_group_set_velocity(NULL, 0.0f, 0.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_rolloff(null)", mmj_sound_group_set_rolloff(NULL, 1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_min_distance(null)", mmj_sound_group_set_min_distance(NULL, 0.1f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_max_distance(null)", mmj_sound_group_set_max_distance(NULL, 10.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_attenuation_model(null)", mmj_sound_group_set_attenuation_model(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_positioning(null)", mmj_sound_group_set_positioning(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_pinned_listener_index(null)", mmj_sound_group_set_pinned_listener_index(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_cone(null)", mmj_sound_group_set_cone(NULL, 0.5f, 1.0f, 1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_doppler_factor(null)", mmj_sound_group_set_doppler_factor(NULL, 1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_directional_attenuation_factor(null)", mmj_sound_group_set_directional_attenuation_factor(NULL, 1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_fade_in_pcm_frames(null)", mmj_sound_group_set_fade_in_pcm_frames(NULL, 0.0f, 1.0f, 64));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_fade_in_milliseconds(null)", mmj_sound_group_set_fade_in_milliseconds(NULL, 0.0f, 1.0f, 50));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_start_time_in_pcm_frames(null)", mmj_sound_group_set_start_time_in_pcm_frames(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_start_time_in_milliseconds(null)", mmj_sound_group_set_start_time_in_milliseconds(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_stop_time_in_pcm_frames(null)", mmj_sound_group_set_stop_time_in_pcm_frames(NULL, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("sound_group_set_stop_time_in_milliseconds(null)", mmj_sound_group_set_stop_time_in_milliseconds(NULL, 1));
    if (rc != 0) return rc;
    (void)mmj_sound_group_get_volume_f32(NULL);
    (void)mmj_sound_group_get_pan_f32(NULL);
    (void)mmj_sound_group_get_pitch_f32(NULL);
    (void)mmj_sound_group_is_spatialization_enabled(NULL);
    (void)mmj_sound_group_get_rolloff(NULL);
    (void)mmj_sound_group_get_min_distance(NULL);
    (void)mmj_sound_group_get_max_distance(NULL);
    (void)mmj_sound_group_get_attenuation_model(NULL);
    (void)mmj_sound_group_get_positioning(NULL);
    (void)mmj_sound_group_get_pinned_listener_index(NULL);
    (void)mmj_sound_group_get_cone_inner_angle(NULL);
    (void)mmj_sound_group_get_cone_outer_angle(NULL);
    (void)mmj_sound_group_get_cone_outer_gain(NULL);
    (void)mmj_sound_group_get_doppler_factor(NULL);
    (void)mmj_sound_group_get_directional_attenuation_factor(NULL);
    (void)mmj_sound_group_get_current_fade_volume(NULL);
    rc = expect_nonzero_rc("sound_group_uninit(null)", mmj_sound_group_uninit(NULL));
    if (rc != 0) return rc;
    i64 = mmj_sound_group_get_time_in_pcm_frames(NULL);
    rc = expect_negative_i64("sound_group_get_time_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("node_attach_output_bus(null)", mmj_node_attach_output_bus(NULL, 0, NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("node_detach_output_bus(null)", mmj_node_detach_output_bus(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("node_set_output_bus_volume(null)", mmj_node_set_output_bus_volume(NULL, 0, 1.0f));
    if (rc != 0) return rc;
    (void)mmj_node_get_output_bus_count(NULL);
    (void)mmj_node_get_output_bus_volume(NULL, 0);

    rc = expect_nonzero_rc("lpf_node_init(null)", mmj_lpf_node_init(NULL, NULL, 2, 48000, 1000.0f, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("lpf_node_set_cutoff(null)", mmj_lpf_node_set_cutoff(NULL, 1000.0f));
    if (rc != 0) return rc;
    (void)mmj_lpf_node_get_cutoff(NULL);
    (void)mmj_lpf_node_get_node(NULL);
    rc = expect_nonzero_rc("lpf_node_uninit(null)", mmj_lpf_node_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("hpf_node_init(null)", mmj_hpf_node_init(NULL, NULL, 2, 48000, 100.0f, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("hpf_node_set_cutoff(null)", mmj_hpf_node_set_cutoff(NULL, 100.0f));
    if (rc != 0) return rc;
    (void)mmj_hpf_node_get_cutoff(NULL);
    (void)mmj_hpf_node_get_node(NULL);
    rc = expect_nonzero_rc("hpf_node_uninit(null)", mmj_hpf_node_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("splitter_node_init(null)", mmj_splitter_node_init(NULL, NULL, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("splitter_node_set_output_bus_volume(null)", mmj_splitter_node_set_output_bus_volume(NULL, 0, 0.5f));
    if (rc != 0) return rc;
    (void)mmj_splitter_node_get_output_bus_volume(NULL, 0);
    (void)mmj_splitter_node_get_node(NULL);
    rc = expect_nonzero_rc("splitter_node_uninit(null)", mmj_splitter_node_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("delay_node_init(null)", mmj_delay_node_init(NULL, NULL, 2, 48000, 64, 0.5f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("delay_node_set_wet(null)", mmj_delay_node_set_wet(NULL, 0.5f));
    if (rc != 0) return rc;
    (void)mmj_delay_node_get_wet(NULL);
    rc = expect_nonzero_rc("delay_node_set_dry(null)", mmj_delay_node_set_dry(NULL, 0.5f));
    if (rc != 0) return rc;
    (void)mmj_delay_node_get_dry(NULL);
    rc = expect_nonzero_rc("delay_node_set_decay(null)", mmj_delay_node_set_decay(NULL, 0.5f));
    if (rc != 0) return rc;
    (void)mmj_delay_node_get_decay(NULL);
    (void)mmj_delay_node_get_node(NULL);
    rc = expect_nonzero_rc("delay_node_uninit(null)", mmj_delay_node_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("resource_manager_init_default(null)", mmj_resource_manager_init_default(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_manager_uninit(null)", mmj_resource_manager_uninit(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_file(null)", mmj_resource_data_source_init_file(NULL, NULL, "./missing.wav", 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_file_w(null)", mmj_resource_data_source_init_file_w(NULL, NULL, "./missing.wav", 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_ex(null)", mmj_resource_data_source_init_ex(NULL, NULL, "./missing.wav", 0, 0, 0, 0, 0, 0, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_ex_w(null)", mmj_resource_data_source_init_ex_w(NULL, NULL, "./missing.wav", 0, 0, 0, 0, 0, 0, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_copy(null)", mmj_resource_data_source_init_copy(NULL, NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_file_with_notifications(null)", mmj_resource_data_source_init_file_with_notifications(NULL, NULL, "./missing.wav", 0, NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_file_with_fences(null)", mmj_resource_data_source_init_file_with_fences(NULL, NULL, "./missing.wav", 0, NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_file_with_notifications_and_fences(null)", mmj_resource_data_source_init_file_with_notifications_and_fences(NULL, NULL, "./missing.wav", 0, NULL, NULL, NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_file_w_with_notifications(null)", mmj_resource_data_source_init_file_w_with_notifications(NULL, NULL, "./missing.wav", 0, NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_init_file_w_with_notifications_and_fences(null)", mmj_resource_data_source_init_file_w_with_notifications_and_fences(NULL, NULL, "./missing.wav", 0, NULL, NULL, NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_wait_result(null)", mmj_resource_data_source_wait_result(NULL, 1, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_result(null)", mmj_resource_data_source_result(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_seek_to_pcm_frame(null)", mmj_resource_data_source_seek_to_pcm_frame(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_seek_pcm_frames(null)", mmj_resource_data_source_seek_pcm_frames(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_set_looping(null)", mmj_resource_data_source_set_looping(NULL, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_set_range_in_pcm_frames(null)", mmj_resource_data_source_set_range_in_pcm_frames(NULL, 0, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_set_loop_point_in_pcm_frames(null)", mmj_resource_data_source_set_loop_point_in_pcm_frames(NULL, 0, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_seek_to_second(null)", mmj_resource_data_source_seek_to_second(NULL, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resource_data_source_seek_seconds(null)", mmj_resource_data_source_seek_seconds(NULL, 0.0f));
    if (rc != 0) return rc;
    i64 = mmj_resource_data_source_get_length_in_pcm_frames(NULL);
    rc = expect_negative_i64("resource_data_source_get_length_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_resource_data_source_get_available_frames(NULL);
    rc = expect_negative_i64("resource_data_source_get_available_frames(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_resource_data_source_get_cursor_in_pcm_frames(NULL);
    rc = expect_negative_i64("resource_data_source_get_cursor_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;
    (void)mmj_resource_data_source_get_cursor_in_seconds(NULL);
    (void)mmj_resource_data_source_get_length_in_seconds(NULL);
    rc = expect_nonzero_rc("resource_data_source_get_format(null)", mmj_resource_data_source_get_format(NULL));
    if (rc != 0) return rc;
    (void)mmj_resource_data_source_get_channels(NULL);
    (void)mmj_resource_data_source_get_sample_rate(NULL);
    (void)mmj_resource_data_source_is_looping(NULL);
    i64 = mmj_resource_data_source_get_range_beg_in_pcm_frames(NULL);
    rc = expect_negative_i64("resource_data_source_get_range_beg_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_resource_data_source_get_range_end_in_pcm_frames(NULL);
    rc = expect_negative_i64("resource_data_source_get_range_end_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_resource_data_source_get_loop_point_beg_in_pcm_frames(NULL);
    rc = expect_negative_i64("resource_data_source_get_loop_point_beg_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_resource_data_source_get_loop_point_end_in_pcm_frames(NULL);
    rc = expect_negative_i64("resource_data_source_get_loop_point_end_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;
    (void)mmj_resource_data_source_flag_async();
    (void)mmj_resource_data_source_flag_stream();
    (void)mmj_resource_data_source_flag_decode();
    (void)mmj_resource_data_source_flag_wait_init();

    rc = expect_nonzero_rc("device_start(null)", mmj_device_start(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_stop(null)", mmj_device_stop(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_set_master_volume_f32(null)", mmj_device_set_master_volume_f32(NULL, 0.2f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_playback_f32(null)", mmj_device_init_playback_f32(NULL, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_capture_f32(null)", mmj_device_init_capture_f32(NULL, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_duplex_f32(null)", mmj_device_init_duplex_f32(NULL, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_f32(null)", mmj_device_init_f32(NULL, 0, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_playback_format(null)", mmj_device_init_playback_format(NULL, 48000, 2, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_capture_format(null)", mmj_device_init_capture_format(NULL, 48000, 2, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_duplex_format(null)", mmj_device_init_duplex_format(NULL, 48000, 2, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_duplex_loopback_format(null)", mmj_device_init_duplex_loopback_format(NULL, 48000, 2, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_playback_ex_f32(null)", mmj_device_init_playback_ex_f32(NULL, 48000, 2, 128, 2, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_capture_ex_f32(null)", mmj_device_init_capture_ex_f32(NULL, 48000, 2, 128, 2, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_duplex_ex_f32(null)", mmj_device_init_duplex_ex_f32(NULL, 48000, 2, 128, 2, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_duplex_loopback_f32(null)", mmj_device_init_duplex_loopback_f32(NULL, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_playback_f32_by_index(null)", mmj_device_init_playback_f32_by_index(NULL, NULL, 0, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_capture_f32_by_index(null)", mmj_device_init_capture_f32_by_index(NULL, NULL, 0, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_set_callback_mode(null)", mmj_device_set_callback_mode(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_set_data_callback(null)", mmj_device_set_data_callback(NULL, NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_set_stop_callback(null)", mmj_device_set_stop_callback(NULL, NULL, NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_clear_callbacks(null)", mmj_device_clear_callbacks(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_wait_for_observed_frames(null)", mmj_device_wait_for_observed_frames(NULL, 1, 1, 1));
    if (rc != 0) return rc;
    (void)mmj_device_is_started(NULL);
    (void)mmj_device_get_kind(NULL);
    (void)mmj_device_get_sample_rate(NULL);
    (void)mmj_device_get_channels(NULL);
    (void)mmj_device_get_callback_mode(NULL);
    i64 = mmj_device_get_observed_frames(NULL);
    rc = expect_negative_i64("device_get_observed_frames(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_reset_observed_frames(null)", mmj_device_reset_observed_frames(NULL));
    if (rc != 0) return rc;
    (void)mmj_device_get_master_volume_milli(NULL);
    rc = expect_nonzero_rc("device_uninit(null)", mmj_device_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("decoder_init_file_f32(null)", mmj_decoder_init_file_f32(NULL, "./missing.wav", 2, 48000));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_file_vfs_f32(null)", mmj_decoder_init_file_vfs_f32(NULL, "./missing.wav", 2, 48000));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_memory_f32(null)", mmj_decoder_init_memory_f32(NULL, NULL, 0, 2, 48000));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_file_format(null)", mmj_decoder_init_file_format(NULL, "./missing.wav", 2, 48000, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_file_vfs_format(null)", mmj_decoder_init_file_vfs_format(NULL, "./missing.wav", 2, 48000, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_memory_format(null)", mmj_decoder_init_memory_format(NULL, NULL, 0, 2, 48000, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_read_pcm_frames_f32(null)", mmj_decoder_read_pcm_frames_f32(NULL, NULL, 0, NULL));
    if (rc != 0) return rc;
    i64 = mmj_decoder_read_pcm_frames_f32_count(NULL, NULL, 0);
    rc = expect_negative_i64("decoder_read_pcm_frames_f32_count(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_seek_to_pcm_frame(null)", mmj_decoder_seek_to_pcm_frame(NULL, 0));
    if (rc != 0) return rc;
    i64 = mmj_decoder_read_probe_f32(NULL, 8);
    rc = expect_negative_i64("decoder_read_probe_f32(null)", i64);
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("encoder_init_wav_file_f32(null)", mmj_encoder_init_wav_file_f32(NULL, "./tmp.wav", 2, 48000));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_init_wav_file_vfs_f32(null)", mmj_encoder_init_wav_file_vfs_f32(NULL, "./tmp.wav", 2, 48000));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_init_wav_file_format(null)", mmj_encoder_init_wav_file_format(NULL, "./tmp.wav", 2, 48000, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_init_wav_file_vfs_format(null)", mmj_encoder_init_wav_file_vfs_format(NULL, "./tmp.wav", 2, 48000, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_write_silence_f32(null)", mmj_encoder_write_silence_f32(NULL, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_uninit(null)", mmj_encoder_uninit(NULL));
    if (rc != 0) return rc;
    i64 = mmj_encoder_write_pcm_frames_f32(NULL, NULL, 4);
    rc = expect_negative_i64("encoder_write_pcm_frames_f32(null)", i64);
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("resampler_init_linear_f32(null)", mmj_resampler_init_linear_f32(NULL, 2, 48000, 44100));
    if (rc != 0) return rc;
    i64 = mmj_resampler_process_f32(NULL, NULL, 0, NULL, 0);
    rc = expect_negative_i64("resampler_process_f32(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_resampler_get_expected_output_frame_count(NULL, 1);
    rc = expect_negative_i64("resampler_get_expected_output_frame_count(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resampler_reset(null)", mmj_resampler_reset(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("resampler_uninit(null)", mmj_resampler_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("channel_converter_init_f32(null)", mmj_channel_converter_init_f32(NULL, 2, 1, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("channel_converter_process_f32(null)", mmj_channel_converter_process_f32(NULL, NULL, NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("channel_converter_uninit(null)", mmj_channel_converter_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("data_converter_init_f32(null)", mmj_data_converter_init_f32(NULL, 2, 1, 48000, 44100));
    if (rc != 0) return rc;
    i64 = mmj_data_converter_process_f32(NULL, NULL, 0, NULL, 0);
    rc = expect_negative_i64("data_converter_process_f32(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_data_converter_get_expected_output_frame_count(NULL, 1);
    rc = expect_negative_i64("data_converter_get_expected_output_frame_count(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_data_converter_get_required_input_frame_count(NULL, 1);
    rc = expect_negative_i64("data_converter_get_required_input_frame_count(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_data_converter_get_input_latency(NULL);
    rc = expect_negative_i64("data_converter_get_input_latency(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_data_converter_get_output_latency(NULL);
    rc = expect_negative_i64("data_converter_get_output_latency(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("data_converter_set_rate(null)", mmj_data_converter_set_rate(NULL, 48000, 44100));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("data_converter_reset(null)", mmj_data_converter_reset(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("data_converter_uninit(null)", mmj_data_converter_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("waveform_init_f32(null)", mmj_waveform_init_f32(NULL, 2, 48000, MMJ_WAVEFORM_TYPE_SINE, 0.2, 440.0));
    if (rc != 0) return rc;
    i64 = mmj_waveform_read_f32(NULL, NULL, 0);
    rc = expect_negative_i64("waveform_read_f32(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("waveform_set_amplitude(null)", mmj_waveform_set_amplitude(NULL, 0.5));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("waveform_set_frequency(null)", mmj_waveform_set_frequency(NULL, 220.0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("waveform_uninit(null)", mmj_waveform_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("noise_init_f32(null)", mmj_noise_init_f32(NULL, 2, MMJ_NOISE_TYPE_WHITE, 7, 0.1));
    if (rc != 0) return rc;
    i64 = mmj_noise_read_f32(NULL, NULL, 0);
    rc = expect_negative_i64("noise_read_f32(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("noise_set_amplitude(null)", mmj_noise_set_amplitude(NULL, 0.2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("noise_set_seed(null)", mmj_noise_set_seed(NULL, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("noise_set_type(null)", mmj_noise_set_type(NULL, MMJ_NOISE_TYPE_PINK));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("noise_uninit(null)", mmj_noise_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("spatializer_init_default(null)", mmj_spatializer_init_default(NULL, 1, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_process_f32(null)", mmj_spatializer_process_f32(NULL, NULL, NULL, NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_listener_init_default(null)", mmj_spatializer_listener_init_default(NULL, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_listener_set_position(null)", mmj_spatializer_listener_set_position(NULL, 0.0f, 0.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_listener_set_direction(null)", mmj_spatializer_listener_set_direction(NULL, 0.0f, 0.0f, -1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_listener_set_world_up(null)", mmj_spatializer_listener_set_world_up(NULL, 0.0f, 1.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_listener_uninit(null)", mmj_spatializer_listener_uninit(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_set_master_volume(null)", mmj_spatializer_set_master_volume(NULL, 1.0f));
    if (rc != 0) return rc;
    (void)mmj_spatializer_get_master_volume(NULL);
    rc = expect_nonzero_rc("spatializer_set_attenuation_model(null)", mmj_spatializer_set_attenuation_model(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_set_positioning(null)", mmj_spatializer_set_positioning(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_set_position(null)", mmj_spatializer_set_position(NULL, 0.0f, 0.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_set_direction(null)", mmj_spatializer_set_direction(NULL, 0.0f, 0.0f, -1.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_set_velocity(null)", mmj_spatializer_set_velocity(NULL, 0.0f, 0.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spatializer_uninit(null)", mmj_spatializer_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("pcm_rb_init_f32(null)", mmj_pcm_rb_init_f32(NULL, 2, 64, 48000));
    if (rc != 0) return rc;
    i64 = mmj_pcm_rb_write_f32(NULL, NULL, 0);
    rc = expect_negative_i64("pcm_rb_write_f32(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_pcm_rb_read_f32(NULL, NULL, 0);
    rc = expect_negative_i64("pcm_rb_read_f32(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_pcm_rb_available_read(NULL);
    rc = expect_negative_i64("pcm_rb_available_read(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_pcm_rb_available_write(NULL);
    rc = expect_negative_i64("pcm_rb_available_write(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("pcm_rb_reset(null)", mmj_pcm_rb_reset(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("pcm_rb_uninit(null)", mmj_pcm_rb_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("log_init(null)", mmj_log_init(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("log_post_info(null)", mmj_log_post_info(NULL, "x"));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("log_register_counting_callback(null)", mmj_log_register_counting_callback(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("log_unregister_counting_callback(null)", mmj_log_unregister_counting_callback(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("log_uninit(null)", mmj_log_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("custom_buffer_data_source_init_f32(null)", mmj_custom_buffer_data_source_init_f32(NULL, NULL, 0, 2, 48000));
    if (rc != 0) return rc;
    i64 = mmj_custom_buffer_data_source_read_f32(NULL, NULL, 0);
    rc = expect_negative_i64("custom_buffer_data_source_read_f32(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("custom_buffer_data_source_seek_to_pcm_frame(null)", mmj_custom_buffer_data_source_seek_to_pcm_frame(NULL, 0));
    if (rc != 0) return rc;
    i64 = mmj_custom_buffer_data_source_get_cursor_in_pcm_frames(NULL);
    rc = expect_negative_i64("custom_buffer_data_source_get_cursor_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;
    i64 = mmj_custom_buffer_data_source_get_length_in_pcm_frames(NULL);
    rc = expect_negative_i64("custom_buffer_data_source_get_length_in_pcm_frames(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("custom_buffer_data_source_uninit(null)", mmj_custom_buffer_data_source_uninit(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("custom_buffer_data_source_get_format(null)", mmj_custom_buffer_data_source_get_format(NULL));
    if (rc != 0) return rc;
    (void)mmj_custom_buffer_data_source_get_channels(NULL);
    (void)mmj_custom_buffer_data_source_get_sample_rate(NULL);
    rc = expect_nonzero_rc("custom_buffer_data_source_set_looping(null)", mmj_custom_buffer_data_source_set_looping(NULL, 1));
    if (rc != 0) return rc;
    (void)mmj_custom_buffer_data_source_is_looping(NULL);

    rc = expect_nonzero_rc("playback_from_buffer_init_f32(null)", mmj_playback_from_buffer_init_f32(NULL, 48000, 2, NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("playback_from_buffer_start(null)", mmj_playback_from_buffer_start(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("playback_from_buffer_stop(null)", mmj_playback_from_buffer_stop(NULL));
    if (rc != 0) return rc;
    (void)mmj_playback_from_buffer_is_finished(NULL);
    i64 = mmj_playback_from_buffer_get_position_in_frames(NULL);
    rc = expect_negative_i64("playback_from_buffer_get_position_in_frames(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("playback_from_buffer_uninit(null)", mmj_playback_from_buffer_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("capture_to_buffer_init_f32(null)", mmj_capture_to_buffer_init_f32(NULL, 48000, 2, NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("capture_to_buffer_start(null)", mmj_capture_to_buffer_start(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("capture_to_buffer_stop(null)", mmj_capture_to_buffer_stop(NULL));
    if (rc != 0) return rc;
    i64 = mmj_capture_to_buffer_get_frames_captured(NULL);
    rc = expect_negative_i64("capture_to_buffer_get_frames_captured(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("capture_to_buffer_reset(null)", mmj_capture_to_buffer_reset(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("capture_to_buffer_uninit(null)", mmj_capture_to_buffer_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("fence_init(null)", mmj_fence_init(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("fence_wait(null)", mmj_fence_wait(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("fence_uninit(null)", mmj_fence_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("mutex_init(null)", mmj_mutex_init(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("mutex_lock(null)", mmj_mutex_lock(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("mutex_unlock(null)", mmj_mutex_unlock(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("mutex_uninit(null)", mmj_mutex_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("event_init(null)", mmj_event_init(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("event_signal(null)", mmj_event_signal(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("event_wait(null)", mmj_event_wait(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("event_uninit(null)", mmj_event_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("semaphore_init(null)", mmj_semaphore_init(NULL, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("semaphore_release(null)", mmj_semaphore_release(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("semaphore_wait(null)", mmj_semaphore_wait(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("semaphore_uninit(null)", mmj_semaphore_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("spinlock_init(null)", mmj_spinlock_init(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spinlock_lock(null)", mmj_spinlock_lock(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spinlock_unlock(null)", mmj_spinlock_unlock(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("spinlock_uninit(null)", mmj_spinlock_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("async_notification_poll_init(null)", mmj_async_notification_poll_init(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("async_notification_poll_signal(null)", mmj_async_notification_poll_signal(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("async_notification_poll_uninit(null)", mmj_async_notification_poll_uninit(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("async_notification_event_init(null)", mmj_async_notification_event_init(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("async_notification_event_signal(null)", mmj_async_notification_event_signal(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("async_notification_event_wait(null)", mmj_async_notification_event_wait(NULL));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("async_notification_event_uninit(null)", mmj_async_notification_event_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("job_queue_init(null)", mmj_job_queue_init(NULL, 0, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("job_queue_post_custom(null)", mmj_job_queue_post_custom(NULL, 1, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("job_queue_post_quit(null)", mmj_job_queue_post_quit(NULL));
    if (rc != 0) return rc;
    i64 = mmj_job_queue_next_code(NULL);
    rc = expect_negative_i64("job_queue_next_code(null)", i64);
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("job_queue_uninit(null)", mmj_job_queue_uninit(NULL));
    if (rc != 0) return rc;

    (void)mmj_job_queue_flag_non_blocking();
    (void)mmj_job_type_quit();
    (void)mmj_job_type_custom();

    rc = expect_nonzero_rc("biquad_node_init(null)", mmj_biquad_node_init(NULL, NULL, 2, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("biquad_node_reinit(null)", mmj_biquad_node_reinit(NULL, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("biquad_peaking_eq_coefficients(null out)", mmj_biquad_peaking_eq_coefficients(48000, 3.0, 1.0, 1000.0, NULL, NULL, NULL, NULL, NULL, NULL));
    if (rc != 0) return rc;
    (void)mmj_biquad_node_get_node(NULL);
    rc = expect_nonzero_rc("biquad_node_uninit(null)", mmj_biquad_node_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("notch_node_init(null)", mmj_notch_node_init(NULL, NULL, 2, 48000, 1.0, 1000.0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("notch_node_reinit(null)", mmj_notch_node_reinit(NULL, 48000, 1.0, 1000.0));
    if (rc != 0) return rc;
    (void)mmj_notch_node_get_node(NULL);
    rc = expect_nonzero_rc("notch_node_uninit(null)", mmj_notch_node_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("peak_node_init(null)", mmj_peak_node_init(NULL, NULL, 2, 48000, 3.0, 1.0, 1000.0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("peak_node_reinit(null)", mmj_peak_node_reinit(NULL, 48000, 3.0, 1.0, 1000.0));
    if (rc != 0) return rc;
    (void)mmj_peak_node_get_node(NULL);
    rc = expect_nonzero_rc("peak_node_uninit(null)", mmj_peak_node_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("loshelf_node_init(null)", mmj_loshelf_node_init(NULL, NULL, 2, 48000, 3.0, 1.0, 500.0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("loshelf_node_reinit(null)", mmj_loshelf_node_reinit(NULL, 48000, 3.0, 1.0, 500.0));
    if (rc != 0) return rc;
    (void)mmj_loshelf_node_get_node(NULL);
    rc = expect_nonzero_rc("loshelf_node_uninit(null)", mmj_loshelf_node_uninit(NULL));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("hishelf_node_init(null)", mmj_hishelf_node_init(NULL, NULL, 2, 48000, 3.0, 1.0, 4000.0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("hishelf_node_reinit(null)", mmj_hishelf_node_reinit(NULL, 48000, 3.0, 1.0, 4000.0));
    if (rc != 0) return rc;
    (void)mmj_hishelf_node_get_node(NULL);
    rc = expect_nonzero_rc("hishelf_node_uninit(null)", mmj_hishelf_node_uninit(NULL));
    if (rc != 0) return rc;

    return 0;
}

static int run_resource_manager_missing_file_smoke_inline(void) {
    void* manager = mmj_resource_manager_create();
    void* data_source = mmj_resource_data_source_create();
    void* poll_a = mmj_async_notification_poll_create();
    void* poll_b = mmj_async_notification_poll_create();
    void* fence_a = mmj_fence_create();
    void* fence_b = mmj_fence_create();
    int rc;

    if (manager == NULL || data_source == NULL || poll_a == NULL || poll_b == NULL || fence_a == NULL || fence_b == NULL) {
        if (fence_b != NULL) mmj_fence_destroy(fence_b);
        if (fence_a != NULL) mmj_fence_destroy(fence_a);
        if (poll_b != NULL) mmj_async_notification_poll_destroy(poll_b);
        if (poll_a != NULL) mmj_async_notification_poll_destroy(poll_a);
        if (data_source != NULL) {
            mmj_resource_data_source_destroy(data_source);
        }
        if (manager != NULL) {
            mmj_resource_manager_destroy(manager);
        }
        return -200;
    }

    rc = mmj_resource_manager_init_default(manager);
    if (rc != 0) {
        mmj_fence_destroy(fence_b);
        mmj_fence_destroy(fence_a);
        mmj_async_notification_poll_destroy(poll_b);
        mmj_async_notification_poll_destroy(poll_a);
        mmj_resource_data_source_destroy(data_source);
        mmj_resource_manager_destroy(manager);
        return rc;
    }

    (void)mmj_async_notification_poll_init(poll_a);
    (void)mmj_async_notification_poll_init(poll_b);
    (void)mmj_fence_init(fence_a);
    (void)mmj_fence_init(fence_b);

    rc = mmj_resource_data_source_init_file(
        data_source,
        manager,
        "/tmp/mmj-native-smoke-missing.wav",
        0
    );
    if (rc == 0) {
        mmj_resource_data_source_uninit(data_source);
        mmj_resource_data_source_destroy(data_source);
        mmj_resource_manager_uninit(manager);
        mmj_resource_manager_destroy(manager);
        return -201;
    }

    rc = mmj_resource_data_source_init_file_w(
        data_source,
        manager,
        "/tmp/mmj-native-smoke-missing.wav",
        0
    );
    if (rc == 0) {
        mmj_resource_data_source_uninit(data_source);
        mmj_resource_data_source_destroy(data_source);
        mmj_resource_manager_uninit(manager);
        mmj_resource_manager_destroy(manager);
        return -202;
    }

    rc = mmj_resource_data_source_init_file_w_with_notifications(
        data_source,
        manager,
        "/tmp/mmj-native-smoke-missing.wav",
        0,
        poll_a,
        poll_b
    );
    if (rc == 0) {
        mmj_resource_data_source_uninit(data_source);
        mmj_resource_data_source_destroy(data_source);
        mmj_resource_manager_uninit(manager);
        mmj_resource_manager_destroy(manager);
        return -203;
    }

    rc = mmj_resource_data_source_init_file_w_with_notifications_and_fences(
        data_source,
        manager,
        "/tmp/mmj-native-smoke-missing.wav",
        0,
        poll_a,
        poll_b,
        fence_a,
        fence_b
    );
    if (rc == 0) {
        mmj_resource_data_source_uninit(data_source);
        mmj_resource_data_source_destroy(data_source);
        mmj_resource_manager_uninit(manager);
        mmj_resource_manager_destroy(manager);
        return -204;
    }

    rc = mmj_resource_data_source_init_ex_w(
        data_source,
        manager,
        "/tmp/mmj-native-smoke-missing.wav",
        0,
        0,
        0,
        0,
        0,
        0,
        0
    );
    if (rc == 0) {
        mmj_resource_data_source_uninit(data_source);
        mmj_resource_data_source_destroy(data_source);
        mmj_resource_manager_uninit(manager);
        mmj_resource_manager_destroy(manager);
        return -205;
    }

    rc = mmj_resource_data_source_uninit(data_source);
    if (rc != 0) {
        mmj_fence_uninit(fence_b);
        mmj_fence_uninit(fence_a);
        mmj_async_notification_poll_uninit(poll_b);
        mmj_async_notification_poll_uninit(poll_a);
        mmj_fence_destroy(fence_b);
        mmj_fence_destroy(fence_a);
        mmj_async_notification_poll_destroy(poll_b);
        mmj_async_notification_poll_destroy(poll_a);
        mmj_resource_data_source_destroy(data_source);
        mmj_resource_manager_uninit(manager);
        mmj_resource_manager_destroy(manager);
        return rc;
    }

    mmj_resource_data_source_destroy(data_source);

    (void)mmj_fence_uninit(fence_b);
    (void)mmj_fence_uninit(fence_a);
    (void)mmj_async_notification_poll_uninit(poll_b);
    (void)mmj_async_notification_poll_uninit(poll_a);
    mmj_fence_destroy(fence_b);
    mmj_fence_destroy(fence_a);
    mmj_async_notification_poll_destroy(poll_b);
    mmj_async_notification_poll_destroy(poll_a);

    rc = mmj_resource_manager_uninit(manager);
    if (rc != 0) {
        mmj_resource_manager_destroy(manager);
        return rc;
    }

    mmj_resource_manager_destroy(manager);
    return 0;
}

static int run_opportunistic_success_path_smoke_inline(void) {
    void* context = mmj_context_create();
    void* engine = mmj_engine_create();
    void* device = mmj_device_create();
    void* decoder = mmj_decoder_create();
    void* encoder = mmj_encoder_create();
    void* manager = mmj_resource_manager_create();
    void* data_source = mmj_resource_data_source_create();
    void* playback_buf = mmj_playback_from_buffer_create();
    void* capture_buf = mmj_capture_to_buffer_create();
    void* spatializer = mmj_spatializer_create();
    void* spatial_listener = mmj_spatializer_listener_create();
    void* sound_group = mmj_sound_group_create();
    void* sound = mmj_sound_create();
    void* biquad = mmj_biquad_node_create();
    void* notch = mmj_notch_node_create();
    void* peak = mmj_peak_node_create();
    void* loshelf = mmj_loshelf_node_create();
    void* hishelf = mmj_hishelf_node_create();
    void* lpf = mmj_lpf_node_create();
    void* hpf = mmj_hpf_node_create();
    void* delay = mmj_delay_node_create();
    void* splitter = mmj_splitter_node_create();
    float scratch[64];
    char name_buf[256];
    uint64_t frames_read = 0;
    int64_t count;
    float coeff_b0 = 0.0f;
    float coeff_b1 = 0.0f;
    float coeff_b2 = 0.0f;
    float coeff_a0 = 1.0f;
    float coeff_a1 = 0.0f;
    float coeff_a2 = 0.0f;
    static float playback_src[32] = {
        0.0f, 0.0f, 0.1f, -0.1f, 0.2f, -0.2f, 0.3f, -0.3f,
        0.4f, -0.4f, 0.5f, -0.5f, 0.6f, -0.6f, 0.7f, -0.7f,
        0.8f, -0.8f, 0.9f, -0.9f, 1.0f, -1.0f, 0.9f, -0.9f,
        0.8f, -0.8f, 0.7f, -0.7f, 0.6f, -0.6f, 0.5f, -0.5f
    };

    /* These calls are allowed to fail depending on host backend availability,
       but when they succeed they exercise deep success-path branches. */
    (void)mmj_play_sine_f32(48000, 2, 440.0, 0.001, 0.1f);
    (void)mmj_play_file_f32("./build/test_assets/sine_440_stereo.wav", 2, 48000);
    (void)mmj_capture_smoke_f32(48000, 2, 0.001);
    (void)mmj_capture_to_wav_f32("/tmp/mmj-capture-quick.wav", 48000, 2, 0.001);
    (void)mmj_duplex_smoke_f32(48000, 2, 0.001);
    (void)mmj_biquad_peaking_eq_coefficients(48000, 3.0, 1.0, 1000.0, &coeff_b0, &coeff_b1, &coeff_b2, &coeff_a0, &coeff_a1, &coeff_a2);

    if (playback_buf != NULL) {
        (void)mmj_playback_from_buffer_uninit(playback_buf);
        (void)mmj_playback_from_buffer_start(playback_buf);
        (void)mmj_playback_from_buffer_stop(playback_buf);
        (void)mmj_playback_from_buffer_is_finished(playback_buf);
        (void)mmj_playback_from_buffer_get_position_in_frames(playback_buf);
        if (mmj_playback_from_buffer_init_f32(playback_buf, 48000, 2, playback_src, 16) == 0) {
            (void)mmj_playback_from_buffer_start(playback_buf);
            (void)mmj_playback_from_buffer_is_finished(playback_buf);
            (void)mmj_playback_from_buffer_get_position_in_frames(playback_buf);
            (void)mmj_playback_from_buffer_stop(playback_buf);
            (void)mmj_playback_from_buffer_uninit(playback_buf);
            (void)mmj_playback_from_buffer_uninit(playback_buf);
        }
    }

    if (capture_buf != NULL) {
        (void)mmj_capture_to_buffer_uninit(capture_buf);
        (void)mmj_capture_to_buffer_start(capture_buf);
        (void)mmj_capture_to_buffer_stop(capture_buf);
        (void)mmj_capture_to_buffer_get_frames_captured(capture_buf);
        (void)mmj_capture_to_buffer_reset(capture_buf);
        if (mmj_capture_to_buffer_init_f32(capture_buf, 48000, 2, scratch, 16) == 0) {
            (void)mmj_capture_to_buffer_start(capture_buf);
            (void)mmj_capture_to_buffer_get_frames_captured(capture_buf);
            (void)mmj_capture_to_buffer_stop(capture_buf);
            (void)mmj_capture_to_buffer_reset(capture_buf);
            (void)mmj_capture_to_buffer_uninit(capture_buf);
            (void)mmj_capture_to_buffer_uninit(capture_buf);
        }
    }

    if (spatializer != NULL && spatial_listener != NULL) {
        if (mmj_spatializer_listener_init_default(spatial_listener, 2) == 0) {
            (void)mmj_spatializer_listener_set_position(spatial_listener, 0.0f, 0.0f, 0.0f);
            (void)mmj_spatializer_listener_set_direction(spatial_listener, 0.0f, 0.0f, -1.0f);
            (void)mmj_spatializer_listener_set_world_up(spatial_listener, 0.0f, 1.0f, 0.0f);
            (void)mmj_spatializer_listener_uninit(spatial_listener);
        }
        if (mmj_spatializer_init_default(spatializer, 1, 2) == 0) {
            (void)mmj_spatializer_set_master_volume(spatializer, 0.8f);
            (void)mmj_spatializer_get_master_volume(spatializer);
            (void)mmj_spatializer_set_attenuation_model(spatializer, 0);
            (void)mmj_spatializer_set_attenuation_model(spatializer, 1);
            (void)mmj_spatializer_set_positioning(spatializer, 0);
            (void)mmj_spatializer_set_positioning(spatializer, 1);
            (void)mmj_spatializer_set_position(spatializer, 0.0f, 0.0f, 0.0f);
            (void)mmj_spatializer_set_direction(spatializer, 0.0f, 0.0f, -1.0f);
            (void)mmj_spatializer_set_velocity(spatializer, 0.0f, 0.0f, 0.0f);
            (void)mmj_spatializer_uninit(spatializer);
        }
    }

    if (decoder != NULL) {
        if (mmj_decoder_init_file_f32(decoder, "./build/test_assets/sine_440_stereo.wav", 2, 48000) == 0) {
            (void)mmj_decoder_read_pcm_frames_f32(decoder, scratch, 8, &frames_read);
            (void)mmj_decoder_read_pcm_frames_f32_count(decoder, scratch, 8);
            (void)mmj_decoder_seek_to_pcm_frame(decoder, 0);
            (void)mmj_decoder_read_probe_f32(decoder, 8);
            (void)mmj_decoder_uninit(decoder);
        }
    }

    if (encoder != NULL) {
        if (mmj_encoder_init_wav_file_f32(encoder, "/tmp/mmj-encode-quick.wav", 2, 48000) == 0) {
            (void)mmj_encoder_write_silence_f32(encoder, 8);
            (void)mmj_encoder_write_pcm_frames_f32(encoder, scratch, 8);
            (void)mmj_encoder_uninit(encoder);
        }
    }

    if (engine != NULL) {
        if (mmj_engine_init_default(engine) == 0) {
            (void)mmj_engine_listener_set_position(engine, 0, 0.0f, 0.0f, 0.0f);
            (void)mmj_engine_listener_set_direction(engine, 0, 0.0f, 0.0f, -1.0f);
            (void)mmj_engine_listener_set_world_up(engine, 0, 0.0f, 1.0f, 0.0f);
            (void)mmj_engine_get_endpoint(engine);

            if (sound_group != NULL && mmj_sound_group_init_default(sound_group, engine) == 0) {
                (void)mmj_sound_group_start(sound_group);
                (void)mmj_sound_group_set_volume_f32(sound_group, 0.8f);
                (void)mmj_sound_group_get_volume_f32(sound_group);
                (void)mmj_sound_group_set_pan_f32(sound_group, 0.0f);
                (void)mmj_sound_group_get_pan_f32(sound_group);
                (void)mmj_sound_group_set_pitch_f32(sound_group, 1.0f);
                (void)mmj_sound_group_get_pitch_f32(sound_group);
                (void)mmj_sound_group_set_spatialization_enabled(sound_group, 1);
                (void)mmj_sound_group_is_spatialization_enabled(sound_group);
                (void)mmj_sound_group_set_position(sound_group, 0.0f, 0.0f, 0.0f);
                (void)mmj_sound_group_set_direction(sound_group, 0.0f, 0.0f, -1.0f);
                (void)mmj_sound_group_set_velocity(sound_group, 0.0f, 0.0f, 0.0f);
                (void)mmj_sound_group_set_rolloff(sound_group, 1.0f);
                (void)mmj_sound_group_get_rolloff(sound_group);
                (void)mmj_sound_group_set_min_distance(sound_group, 0.1f);
                (void)mmj_sound_group_get_min_distance(sound_group);
                (void)mmj_sound_group_set_max_distance(sound_group, 10.0f);
                (void)mmj_sound_group_get_max_distance(sound_group);
                (void)mmj_sound_group_set_attenuation_model(sound_group, 1);
                (void)mmj_sound_group_get_attenuation_model(sound_group);
                (void)mmj_sound_group_set_positioning(sound_group, 0);
                (void)mmj_sound_group_get_positioning(sound_group);
                (void)mmj_sound_group_set_pinned_listener_index(sound_group, 0);
                (void)mmj_sound_group_get_pinned_listener_index(sound_group);
                (void)mmj_sound_group_set_cone(sound_group, 0.5f, 1.0f, 1.0f);
                (void)mmj_sound_group_get_cone_inner_angle(sound_group);
                (void)mmj_sound_group_get_cone_outer_angle(sound_group);
                (void)mmj_sound_group_get_cone_outer_gain(sound_group);
                (void)mmj_sound_group_set_doppler_factor(sound_group, 1.0f);
                (void)mmj_sound_group_get_doppler_factor(sound_group);
                (void)mmj_sound_group_set_directional_attenuation_factor(sound_group, 1.0f);
                (void)mmj_sound_group_get_directional_attenuation_factor(sound_group);
                (void)mmj_sound_group_set_fade_in_pcm_frames(sound_group, 0.0f, 1.0f, 16);
                (void)mmj_sound_group_set_fade_in_milliseconds(sound_group, 0.0f, 1.0f, 1);
                (void)mmj_sound_group_get_current_fade_volume(sound_group);
                (void)mmj_sound_group_set_start_time_in_pcm_frames(sound_group, 1);
                (void)mmj_sound_group_set_start_time_in_milliseconds(sound_group, 1);
                (void)mmj_sound_group_set_stop_time_in_pcm_frames(sound_group, 2);
                (void)mmj_sound_group_set_stop_time_in_milliseconds(sound_group, 2);
                (void)mmj_sound_group_get_time_in_pcm_frames(sound_group);

                if (sound != NULL && mmj_sound_init_from_file_in_group(sound, engine, sound_group, "./build/test_assets/sine_440_stereo.wav") == 0) {
                    (void)mmj_sound_start(sound);
                    (void)mmj_sound_pause(sound);
                    (void)mmj_sound_stop(sound);
                    (void)mmj_sound_seek_to_pcm_frame(sound, 0);
                    (void)mmj_sound_set_looping(sound, 1);
                    (void)mmj_sound_set_volume_f32(sound, 0.3f);
                    (void)mmj_sound_set_spatialization_enabled(sound, 1);
                    (void)mmj_sound_set_position(sound, 0.0f, 0.0f, 0.0f);
                    (void)mmj_sound_set_rolloff(sound, 1.0f);
                    (void)mmj_sound_set_min_distance(sound, 0.1f);
                    (void)mmj_sound_set_max_distance(sound, 10.0f);
                    (void)mmj_sound_get_cursor_in_pcm_frames(sound);
                    (void)mmj_sound_get_time_in_milliseconds(sound);
                    (void)mmj_sound_is_finished(sound);
                    (void)mmj_sound_get_node(sound);
                    (void)mmj_sound_uninit(sound);
                }

                (void)mmj_sound_group_stop(sound_group);
                (void)mmj_sound_group_uninit(sound_group);
            }

            if (biquad != NULL && mmj_biquad_node_init(biquad, engine, 2, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f) == 0) {
                (void)mmj_biquad_node_reinit(biquad, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f);
                (void)mmj_biquad_node_get_node(biquad);
                (void)mmj_biquad_node_uninit(biquad);
            }
            if (notch != NULL && mmj_notch_node_init(notch, engine, 2, 48000, 1.0, 1000.0) == 0) {
                (void)mmj_notch_node_reinit(notch, 48000, 1.0, 1000.0);
                (void)mmj_notch_node_get_node(notch);
                (void)mmj_notch_node_uninit(notch);
            }
            if (peak != NULL && mmj_peak_node_init(peak, engine, 2, 48000, 3.0, 1.0, 1000.0) == 0) {
                (void)mmj_peak_node_reinit(peak, 48000, 3.0, 1.0, 1000.0);
                (void)mmj_peak_node_get_node(peak);
                (void)mmj_peak_node_uninit(peak);
            }
            if (loshelf != NULL && mmj_loshelf_node_init(loshelf, engine, 2, 48000, 3.0, 1.0, 500.0) == 0) {
                (void)mmj_loshelf_node_reinit(loshelf, 48000, 3.0, 1.0, 500.0);
                (void)mmj_loshelf_node_get_node(loshelf);
                (void)mmj_loshelf_node_uninit(loshelf);
            }
            if (hishelf != NULL && mmj_hishelf_node_init(hishelf, engine, 2, 48000, 3.0, 1.0, 4000.0) == 0) {
                (void)mmj_hishelf_node_reinit(hishelf, 48000, 3.0, 1.0, 4000.0);
                (void)mmj_hishelf_node_get_node(hishelf);
                (void)mmj_hishelf_node_uninit(hishelf);
            }

            if (lpf != NULL) {
                (void)mmj_lpf_node_init(lpf, engine, 2, 48000, 1000.0f, 2);
                (void)mmj_lpf_node_set_cutoff(lpf, 1200.0f);
                (void)mmj_lpf_node_get_cutoff(lpf);
                (void)mmj_lpf_node_get_node(lpf);
                (void)mmj_lpf_node_uninit(lpf);
            }
            if (hpf != NULL) {
                (void)mmj_hpf_node_init(hpf, engine, 2, 48000, 100.0f, 2);
                (void)mmj_hpf_node_set_cutoff(hpf, 90.0f);
                (void)mmj_hpf_node_get_cutoff(hpf);
                (void)mmj_hpf_node_get_node(hpf);
                (void)mmj_hpf_node_uninit(hpf);
            }
            if (delay != NULL) {
                (void)mmj_delay_node_init(delay, engine, 2, 48000, 64, 0.5f);
                (void)mmj_delay_node_set_wet(delay, 0.4f);
                (void)mmj_delay_node_get_wet(delay);
                (void)mmj_delay_node_set_dry(delay, 0.6f);
                (void)mmj_delay_node_get_dry(delay);
                (void)mmj_delay_node_set_decay(delay, 0.3f);
                (void)mmj_delay_node_get_decay(delay);
                (void)mmj_delay_node_get_node(delay);
                (void)mmj_delay_node_uninit(delay);
            }
            if (splitter != NULL) {
                (void)mmj_splitter_node_init(splitter, engine, 2);
                (void)mmj_splitter_node_set_output_bus_volume(splitter, 0, 0.5f);
                (void)mmj_splitter_node_get_output_bus_volume(splitter, 0);
                (void)mmj_splitter_node_get_node(splitter);
                (void)mmj_splitter_node_uninit(splitter);
            }
            (void)mmj_engine_uninit(engine);
        }
        mmj_engine_destroy(engine);
    }

    if (context != NULL) {
        if (mmj_context_init_default(context) == 0) {
            count = mmj_context_get_playback_device_count(context);
            if (count > 0) {
                (void)mmj_context_get_playback_device_name(context, 0, name_buf, (uint32_t)sizeof(name_buf));
            }
            count = mmj_context_get_capture_device_count(context);
            if (count > 0) {
                (void)mmj_context_get_capture_device_name(context, 0, name_buf, (uint32_t)sizeof(name_buf));
            }
            (void)mmj_context_uninit(context);
        }
        mmj_context_destroy(context);
    }

    if (device != NULL) {
        (void)mmj_device_set_data_callback(device, NULL, NULL);
        (void)mmj_device_set_stop_callback(device, NULL, NULL);
        (void)mmj_device_set_stop_callback(device, NULL, &frames_read);
        (void)mmj_device_clear_callbacks(device);
        if (mmj_device_init_capture_ex_f32(device, 48000, 2, 128, 2, 1) == 0) {
            (void)mmj_device_start(device);
            (void)mmj_device_stop(device);
            (void)mmj_device_uninit(device);
        }
        if (mmj_device_init_duplex_ex_f32(device, 48000, 2, 128, 2, 0) == 0) {
            (void)mmj_device_start(device);
            (void)mmj_device_stop(device);
            (void)mmj_device_uninit(device);
        }
        if (mmj_device_init_playback_ex_f32(device, 48000, 2, 128, 2, 1) == 0) {
            (void)mmj_device_set_callback_mode(device, 1);
            (void)mmj_device_get_callback_mode(device);
            (void)mmj_device_get_kind(device);
            (void)mmj_device_get_sample_rate(device);
            (void)mmj_device_get_channels(device);
            (void)mmj_device_set_master_volume_f32(device, 0.1f);
            (void)mmj_device_get_master_volume_milli(device);
            (void)mmj_device_start(device);
            (void)mmj_device_is_started(device);
            (void)mmj_device_stop(device);
            (void)mmj_device_reset_observed_frames(device);
            (void)mmj_device_get_observed_frames(device);
            (void)mmj_device_uninit(device);
            (void)mmj_device_uninit(device);
        }
        mmj_device_destroy(device);
    }

    if (manager != NULL && data_source != NULL) {
        if (mmj_resource_manager_init_default(manager) == 0) {
            if (mmj_resource_data_source_init_file(data_source, manager, "./build/test_assets/sine_440_stereo.wav", 0) == 0) {
                (void)mmj_resource_data_source_result(data_source);
                (void)mmj_resource_data_source_wait_result(data_source, 10, 1);
                (void)mmj_resource_data_source_get_length_in_pcm_frames(data_source);
                (void)mmj_resource_data_source_get_available_frames(data_source);
                (void)mmj_resource_data_source_get_cursor_in_pcm_frames(data_source);
                (void)mmj_resource_data_source_get_cursor_in_seconds(data_source);
                (void)mmj_resource_data_source_get_length_in_seconds(data_source);
                (void)mmj_resource_data_source_get_format(data_source);
                (void)mmj_resource_data_source_get_channels(data_source);
                (void)mmj_resource_data_source_get_sample_rate(data_source);
                (void)mmj_resource_data_source_set_looping(data_source, 1);
                (void)mmj_resource_data_source_is_looping(data_source);
                (void)mmj_resource_data_source_set_range_in_pcm_frames(data_source, 0, 128);
                (void)mmj_resource_data_source_get_range_beg_in_pcm_frames(data_source);
                (void)mmj_resource_data_source_get_range_end_in_pcm_frames(data_source);
                (void)mmj_resource_data_source_set_loop_point_in_pcm_frames(data_source, 0, 64);
                (void)mmj_resource_data_source_get_loop_point_beg_in_pcm_frames(data_source);
                (void)mmj_resource_data_source_get_loop_point_end_in_pcm_frames(data_source);
                (void)mmj_resource_data_source_seek_to_pcm_frame(data_source, 0);
                (void)mmj_resource_data_source_seek_pcm_frames(data_source, 4);
                (void)mmj_resource_data_source_seek_to_second(data_source, 0.0f);
                (void)mmj_resource_data_source_seek_seconds(data_source, 0.0f);
                (void)mmj_resource_data_source_uninit(data_source);
            }
            if (mmj_resource_data_source_init_file_w(data_source, manager, "./build/test_assets/sine_440_stereo.wav", 0) == 0) {
                (void)mmj_resource_data_source_result(data_source);
                (void)mmj_resource_data_source_uninit(data_source);
            }
            (void)mmj_resource_manager_uninit(manager);
        }
        mmj_resource_data_source_destroy(data_source);
        mmj_resource_manager_destroy(manager);
    }

    if (lpf != NULL) mmj_lpf_node_destroy(lpf);
    if (hpf != NULL) mmj_hpf_node_destroy(hpf);
    if (delay != NULL) mmj_delay_node_destroy(delay);
    if (splitter != NULL) mmj_splitter_node_destroy(splitter);
    if (playback_buf != NULL) mmj_playback_from_buffer_destroy(playback_buf);
    if (capture_buf != NULL) mmj_capture_to_buffer_destroy(capture_buf);
    if (spatializer != NULL) mmj_spatializer_destroy(spatializer);
    if (spatial_listener != NULL) mmj_spatializer_listener_destroy(spatial_listener);
    if (sound != NULL) mmj_sound_destroy(sound);
    if (sound_group != NULL) mmj_sound_group_destroy(sound_group);
    if (biquad != NULL) mmj_biquad_node_destroy(biquad);
    if (notch != NULL) mmj_notch_node_destroy(notch);
    if (peak != NULL) mmj_peak_node_destroy(peak);
    if (loshelf != NULL) mmj_loshelf_node_destroy(loshelf);
    if (hishelf != NULL) mmj_hishelf_node_destroy(hishelf);
    if (decoder != NULL) mmj_decoder_destroy(decoder);
    if (encoder != NULL) mmj_encoder_destroy(encoder);

    return 0;
}

static int run_create_destroy_sweep_smoke_inline(void) {
    void* handle;

    handle = mmj_context_create(); if (handle == NULL) return -300; mmj_context_destroy(handle);
    handle = mmj_engine_create(); if (handle == NULL) return -301; mmj_engine_destroy(handle);
    handle = mmj_sound_create(); if (handle == NULL) return -302; mmj_sound_destroy(handle);
    handle = mmj_sound_group_create(); if (handle == NULL) return -303; mmj_sound_group_destroy(handle);

    handle = mmj_lpf_node_create(); if (handle == NULL) return -304; mmj_lpf_node_destroy(handle);
    handle = mmj_hpf_node_create(); if (handle == NULL) return -305; mmj_hpf_node_destroy(handle);
    handle = mmj_delay_node_create(); if (handle == NULL) return -306; mmj_delay_node_destroy(handle);
    handle = mmj_splitter_node_create(); if (handle == NULL) return -307; mmj_splitter_node_destroy(handle);

    handle = mmj_resource_manager_create(); if (handle == NULL) return -308; mmj_resource_manager_destroy(handle);
    handle = mmj_job_queue_create(); if (handle == NULL) return -309; mmj_job_queue_destroy(handle);
    handle = mmj_async_notification_poll_create(); if (handle == NULL) return -310; mmj_async_notification_poll_destroy(handle);
    handle = mmj_async_notification_event_create(); if (handle == NULL) return -311; mmj_async_notification_event_destroy(handle);
    handle = mmj_fence_create(); if (handle == NULL) return -312; mmj_fence_destroy(handle);

    handle = mmj_mutex_create(); if (handle == NULL) return -313; mmj_mutex_destroy(handle);
    handle = mmj_event_create(); if (handle == NULL) return -314; mmj_event_destroy(handle);
    handle = mmj_semaphore_create(); if (handle == NULL) return -315; mmj_semaphore_destroy(handle);
    handle = mmj_spinlock_create(); if (handle == NULL) return -316; mmj_spinlock_destroy(handle);
    handle = mmj_resource_data_source_create(); if (handle == NULL) return -317; mmj_resource_data_source_destroy(handle);

    handle = mmj_device_create(); if (handle == NULL) return -318; mmj_device_destroy(handle);
    handle = mmj_decoder_create(); if (handle == NULL) return -319; mmj_decoder_destroy(handle);
    handle = mmj_encoder_create(); if (handle == NULL) return -320; mmj_encoder_destroy(handle);

    handle = mmj_resampler_create(); if (handle == NULL) return -321; mmj_resampler_destroy(handle);
    handle = mmj_channel_converter_create(); if (handle == NULL) return -322; mmj_channel_converter_destroy(handle);
    handle = mmj_data_converter_create(); if (handle == NULL) return -323; mmj_data_converter_destroy(handle);
    handle = mmj_waveform_create(); if (handle == NULL) return -324; mmj_waveform_destroy(handle);
    handle = mmj_noise_create(); if (handle == NULL) return -325; mmj_noise_destroy(handle);
    handle = mmj_spatializer_listener_create(); if (handle == NULL) return -326; mmj_spatializer_listener_destroy(handle);
    handle = mmj_spatializer_create(); if (handle == NULL) return -327; mmj_spatializer_destroy(handle);

    handle = mmj_pcm_rb_create(); if (handle == NULL) return -328; mmj_pcm_rb_destroy(handle);
    handle = mmj_log_create(); if (handle == NULL) return -329; mmj_log_destroy(handle);

    handle = mmj_playback_from_buffer_create(); if (handle == NULL) return -330; mmj_playback_from_buffer_destroy(handle);
    handle = mmj_capture_to_buffer_create(); if (handle == NULL) return -331; mmj_capture_to_buffer_destroy(handle);
    handle = mmj_custom_buffer_data_source_create(); if (handle == NULL) return -332; mmj_custom_buffer_data_source_destroy(handle);

    handle = mmj_biquad_node_create(); if (handle == NULL) return -333; mmj_biquad_node_destroy(handle);
    handle = mmj_notch_node_create(); if (handle == NULL) return -334; mmj_notch_node_destroy(handle);
    handle = mmj_peak_node_create(); if (handle == NULL) return -335; mmj_peak_node_destroy(handle);
    handle = mmj_loshelf_node_create(); if (handle == NULL) return -336; mmj_loshelf_node_destroy(handle);
    handle = mmj_hishelf_node_create(); if (handle == NULL) return -337; mmj_hishelf_node_destroy(handle);

    return 0;
}

static int run_invalid_args_and_format_sweep_smoke_inline(void) {
    int rc;
    unsigned char tiny_invalid_audio[4] = {0x00, 0x11, 0x22, 0x33};
    const char* definitely_missing_file = "/tmp/mmj-definitely-missing-audio.wav";
    const char* definitely_missing_parent_file = "/tmp/mmj-no-such-dir/out.wav";
    void* device = mmj_device_create();
    void* decoder = mmj_decoder_create();
    void* encoder = mmj_encoder_create();

    rc = expect_nonzero_rc("play_sine_f32(invalid sample rate)", mmj_play_sine_f32(0, 2, 440.0, 0.1, 0.1f));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("play_file_f32(null path)", mmj_play_file_f32(NULL, 2, 48000));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("capture_smoke_f32(invalid sample rate)", mmj_capture_smoke_f32(0, 2, 0.1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("capture_to_wav_f32(null path)", mmj_capture_to_wav_f32(NULL, 48000, 2, 0.1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("duplex_smoke_f32(invalid sample rate)", mmj_duplex_smoke_f32(0, 2, 0.1));
    if (rc != 0) return rc;

    if (device == NULL || decoder == NULL || encoder == NULL) {
        if (device != NULL) mmj_device_destroy(device);
        if (decoder != NULL) mmj_decoder_destroy(decoder);
        if (encoder != NULL) mmj_encoder_destroy(encoder);
        return -400;
    }

    rc = expect_nonzero_rc("device_init_playback_format(u8, invalid sample rate)", mmj_device_init_playback_format(device, 0, 2, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_playback_format(s16, invalid sample rate)", mmj_device_init_playback_format(device, 0, 2, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_playback_format(s24, invalid sample rate)", mmj_device_init_playback_format(device, 0, 2, 3));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_playback_format(s32, invalid sample rate)", mmj_device_init_playback_format(device, 0, 2, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_playback_format(f32, invalid sample rate)", mmj_device_init_playback_format(device, 0, 2, 5));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_playback_format(invalid format)", mmj_device_init_playback_format(device, 48000, 2, 999));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("device_init_capture_format(s16, invalid sample rate)", mmj_device_init_capture_format(device, 0, 2, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_duplex_format(s32, invalid sample rate)", mmj_device_init_duplex_format(device, 0, 2, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_capture_ex_f32(invalid sample rate)", mmj_device_init_capture_ex_f32(device, 0, 2, 128, 2, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_duplex_ex_f32(invalid sample rate)", mmj_device_init_duplex_ex_f32(device, 0, 2, 128, 2, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_capture_ex_f32(invalid period count)", mmj_device_init_capture_ex_f32(device, 48000, 2, 128, 17, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_duplex_ex_f32(invalid period count)", mmj_device_init_duplex_ex_f32(device, 48000, 2, 128, 17, 0));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("device_init_duplex_loopback_format(u8, invalid sample rate)", mmj_device_init_duplex_loopback_format(device, 0, 2, 1));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("decoder_init_file_format(u8)", mmj_decoder_init_file_format(decoder, definitely_missing_file, 2, 48000, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_file_format(s16)", mmj_decoder_init_file_format(decoder, definitely_missing_file, 2, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_file_format(s24)", mmj_decoder_init_file_format(decoder, definitely_missing_file, 2, 48000, 3));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_file_format(s32)", mmj_decoder_init_file_format(decoder, definitely_missing_file, 2, 48000, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_file_format(f32)", mmj_decoder_init_file_format(decoder, definitely_missing_file, 2, 48000, 5));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_file_format(invalid format)", mmj_decoder_init_file_format(decoder, definitely_missing_file, 2, 48000, 999));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("decoder_init_file_vfs_format(s16)", mmj_decoder_init_file_vfs_format(decoder, definitely_missing_file, 2, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_memory_format(u8)", mmj_decoder_init_memory_format(decoder, tiny_invalid_audio, 4, 2, 48000, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_memory_format(s24)", mmj_decoder_init_memory_format(decoder, tiny_invalid_audio, 4, 2, 48000, 3));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("decoder_init_memory_format(invalid format)", mmj_decoder_init_memory_format(decoder, tiny_invalid_audio, 4, 2, 48000, 999));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("encoder_init_wav_file_format(u8 missing dir)", mmj_encoder_init_wav_file_format(encoder, definitely_missing_parent_file, 2, 48000, 1));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_init_wav_file_format(s16 missing dir)", mmj_encoder_init_wav_file_format(encoder, definitely_missing_parent_file, 2, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_init_wav_file_format(s24 missing dir)", mmj_encoder_init_wav_file_format(encoder, definitely_missing_parent_file, 2, 48000, 3));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_init_wav_file_format(s32 missing dir)", mmj_encoder_init_wav_file_format(encoder, definitely_missing_parent_file, 2, 48000, 4));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_init_wav_file_format(f32 missing dir)", mmj_encoder_init_wav_file_format(encoder, definitely_missing_parent_file, 2, 48000, 5));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_init_wav_file_format(invalid format)", mmj_encoder_init_wav_file_format(encoder, definitely_missing_parent_file, 2, 48000, 999));
    if (rc != 0) return rc;

    rc = expect_nonzero_rc("encoder_init_wav_file_vfs_format(s16 missing dir)", mmj_encoder_init_wav_file_vfs_format(encoder, definitely_missing_parent_file, 2, 48000, 2));
    if (rc != 0) return rc;
    rc = expect_nonzero_rc("encoder_init_wav_file_vfs_format(invalid format)", mmj_encoder_init_wav_file_vfs_format(encoder, definitely_missing_parent_file, 2, 48000, 999));
    if (rc != 0) return rc;

    mmj_device_destroy(device);
    mmj_decoder_destroy(decoder);
    mmj_encoder_destroy(encoder);
    return 0;
}

static int run_binding_smoke_suite(void) {
    int result;

    result = run_named_smoke("job_queue_smoke", mmj_job_queue_smoke);
    if (result != 0) return result;
    result = run_named_smoke("job_queue_invalid_args_smoke", mmj_job_queue_invalid_args_smoke);
    if (result != 0) return result;

    result = run_named_smoke("sync_primitives_smoke", mmj_sync_primitives_smoke);
    if (result != 0) return result;
    result = run_named_smoke("sync_primitives_invalid_args_smoke", mmj_sync_primitives_invalid_args_smoke);
    if (result != 0) return result;

    result = run_named_smoke("async_notification_poll_smoke", mmj_async_notification_poll_smoke);
    if (result != 0) return result;
    result = run_named_smoke("async_notification_poll_invalid_args_smoke", mmj_async_notification_poll_invalid_args_smoke);
    if (result != 0) return result;
    result = run_named_smoke("async_notification_event_smoke", mmj_async_notification_event_smoke);
    if (result != 0) return result;
    result = run_named_smoke("async_notification_event_invalid_args_smoke", mmj_async_notification_event_invalid_args_smoke);
    if (result != 0) return result;

    result = run_named_smoke("resampler_linear_smoke", mmj_resampler_linear_smoke);
    if (result != 0) return result;
    result = run_named_smoke("resampler_invalid_rate_smoke", mmj_resampler_invalid_rate_smoke);
    if (result != 0) return result;
    result = run_named_smoke("channel_converter_stereo_to_mono_smoke", mmj_channel_converter_stereo_to_mono_smoke);
    if (result != 0) return result;
    result = run_named_smoke("channel_converter_invalid_channels_smoke", mmj_channel_converter_invalid_channels_smoke);
    if (result != 0) return result;

    result = run_named_smoke("data_converter_smoke", mmj_data_converter_smoke);
    if (result != 0) return result;
    result = run_named_smoke("data_converter_invalid_args_smoke", mmj_data_converter_invalid_args_smoke);
    if (result != 0) return result;

    result = run_named_smoke("waveform_sine_smoke", mmj_waveform_sine_smoke);
    if (result != 0) return result;
    result = run_named_smoke("waveform_invalid_args_smoke", mmj_waveform_invalid_args_smoke);
    if (result != 0) return result;
    result = run_named_smoke("noise_smoke", mmj_noise_smoke);
    if (result != 0) return result;
    result = run_named_smoke("noise_invalid_args_smoke", mmj_noise_invalid_args_smoke);
    if (result != 0) return result;

    result = run_named_smoke("spatializer_smoke", mmj_spatializer_smoke);
    if (result != 0) return result;
    result = run_named_smoke("spatializer_invalid_args_smoke", mmj_spatializer_invalid_args_smoke);
    if (result != 0) return result;

    result = run_named_smoke("decoder_memory_smoke", mmj_decoder_memory_smoke);
    if (result != 0) return result;
    result = run_named_smoke("decoder_memory_invalid_args_smoke", mmj_decoder_memory_invalid_args_smoke);
    if (result != 0) return result;

    result = run_named_smoke("pcm_rb_smoke", mmj_pcm_rb_smoke);
    if (result != 0) return result;
    result = run_named_smoke("pcm_rb_overflow_smoke", mmj_pcm_rb_overflow_smoke);
    if (result != 0) return result;
    result = run_named_smoke("pcm_rb_invalid_args_smoke", mmj_pcm_rb_invalid_args_smoke);
    if (result != 0) return result;

    result = run_named_smoke("custom_buffer_data_source_smoke", mmj_custom_buffer_data_source_smoke);
    if (result != 0) return result;
    result = run_named_smoke("custom_buffer_data_source_invalid_args_smoke", mmj_custom_buffer_data_source_invalid_args_smoke);
    if (result != 0) return result;

    result = run_named_smoke("logging_inline_smoke", run_logging_smoke_inline);
    if (result != 0) return result;

    result = run_named_smoke("null_guard_suite", run_null_guard_suite);
    if (result != 0) return result;

    result = run_named_smoke("resource_manager_missing_file_inline_smoke", run_resource_manager_missing_file_smoke_inline);
    if (result != 0) return result;

    result = run_named_smoke("create_destroy_sweep_inline_smoke", run_create_destroy_sweep_smoke_inline);
    if (result != 0) return result;

    result = run_named_smoke("invalid_args_and_format_sweep_inline_smoke", run_invalid_args_and_format_sweep_smoke_inline);
    if (result != 0) return result;

    result = run_named_smoke("callback_path_smoke", mmj_callback_path_smoke);
    if (result != 0) return result;

    result = run_named_smoke("opportunistic_success_path_smoke", run_opportunistic_success_path_smoke_inline);
    if (result != 0) return result;

    result = run_named_smoke("device_test_callback_smoke", run_device_test_callback_smoke_inline);
    if (result != 0) return result;

    return 0;
}

int main(void) {
    int result;
    const char* run_suite_env;
    const char* skip_playback_env;
    int run_suite = 0;
    int skip_playback = 0;

    printf("miniaudio version: %s\n", mmj_miniaudio_version());
    printf("result description sanity: %s\n", mmj_result_description(-1));

    run_suite_env = getenv("MMJ_NATIVE_RUN_SUITE");
    skip_playback_env = getenv("MMJ_NATIVE_SKIP_PLAYBACK");

    if (run_suite_env != NULL && strcmp(run_suite_env, "1") == 0) {
        run_suite = 1;
    }

    if (skip_playback_env != NULL && strcmp(skip_playback_env, "1") == 0) {
        skip_playback = 1;
    }

    if (!skip_playback) {
        printf("native playback smoke: 440Hz, 2 seconds\n");
        result = mmj_play_sine_f32(48000, 2, 440.0, 2.0, 0.15f);
        if (result != 0) {
            printf("failed: playback_smoke -> %s (%d)\n", mmj_result_description(result), result);
            return 1;
        }

        printf("ok: playback_smoke\n");
    } else {
        printf("skip: playback_smoke (MMJ_NATIVE_SKIP_PLAYBACK=1)\n");
    }

    if (run_suite) {
        printf("running native binding smoke suite\n");
        result = run_binding_smoke_suite();
        if (result != 0) {
            return 1;
        }
        printf("ok: native binding smoke suite\n");
    } else {
        printf("skip: binding smoke suite (set MMJ_NATIVE_RUN_SUITE=1)\n");
    }

    printf("ok\n");
    return 0;
}
