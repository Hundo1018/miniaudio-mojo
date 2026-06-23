from miniaudio import run_playback_file_smoke, run_playback_smoke
from miniaudio_biquad import run_biquad_invalid_q_smoke, run_biquad_peaking_eq_smoke
from miniaudio_binding_contract import run_mojo_binding_contract_smoke, run_mojo_decoder_encoder_contract_suite, run_mojo_device_init_ex_contract_suite, run_mojo_handle_lifecycle_contract_smoke
from miniaudio_capture import run_capture_file_smoke, run_capture_smoke, run_encoder_wav_smoke
from miniaudio_context import run_context_smoke
from miniaudio_data_converter import run_data_converter_invalid_args_smoke, run_data_converter_smoke
from miniaudio_decoder import run_decoder_memory_invalid_args_smoke, run_decoder_memory_output_format_matrix_smoke, run_decoder_memory_smoke, run_decoder_output_format_matrix_smoke, run_decoder_read_smoke, run_decoder_smoke, run_decoder_vfs_smoke
from miniaudio_custom_data_source import run_custom_buffer_data_source_invalid_args_smoke, run_custom_buffer_data_source_smoke
from miniaudio_encoder import run_encoder_invalid_state_smoke, run_encoder_vfs_wav_smoke, run_encoder_wav_format_matrix_smoke, run_encoder_write_frames_smoke
from miniaudio_device import run_device_callback_longrun_smoke, run_device_callback_smoke, run_device_config_smoke, run_device_control_smoke, run_device_format_matrix_smoke, run_device_init_ex_smoke, run_device_volume_smoke, run_device_user_callback_smoke
from miniaudio_devices import run_device_select_smoke, run_devices_smoke
from miniaudio_duplex import run_duplex_control_smoke, run_duplex_smoke
from miniaudio_async_notification import run_async_notification_event_invalid_args_smoke, run_async_notification_event_smoke, run_async_notification_poll_invalid_args_smoke, run_async_notification_poll_smoke
from miniaudio_engine import run_engine_listener_control_smoke, run_engine_play_sound_smoke
from miniaudio_effects import run_hpf_node_smoke, run_lpf_node_smoke, run_reverb_like_chain_smoke, run_splitter_dry_wet_smoke
from miniaudio_job_queue import run_job_queue_invalid_args_smoke, run_job_queue_smoke
from miniaudio_logging import run_logging_invalid_state_smoke, run_logging_smoke
from miniaudio_noise import run_noise_invalid_args_smoke, run_noise_smoke
from miniaudio_node import run_node_attach_detach_smoke, run_node_routing_scene_smoke
from miniaudio_resource_manager import run_resource_manager_async_poll_smoke, run_resource_manager_init_copy_smoke, run_resource_manager_init_ex_smoke, run_resource_manager_init_ex_w_smoke, run_resource_manager_init_w_smoke, run_resource_manager_pipeline_fence_smoke, run_resource_manager_pipeline_notification_smoke, run_resource_manager_pipeline_notification_w_smoke, run_resource_manager_pipeline_notifications_and_fences_smoke, run_resource_manager_pipeline_notifications_and_fences_w_smoke, run_resource_manager_smoke, run_resource_manager_streaming_async_smoke
from miniaudio_data_source import run_data_source_extended_smoke, run_data_source_invalid_smoke, run_data_source_loop_point_smoke, run_data_source_range_smoke
from miniaudio_eq_nodes import run_eq_nodes_invalid_smoke, run_hishelf_node_smoke, run_loshelf_node_smoke, run_notch_node_smoke, run_peak_node_smoke
from miniaudio_ring_buffer import run_pcm_rb_handle_smoke, run_pcm_rb_invalid_args_smoke, run_pcm_rb_overflow_smoke, run_pcm_rb_smoke
from miniaudio_resampler import run_channel_converter_init_mode_smoke, run_channel_converter_invalid_channels_smoke, run_channel_converter_stereo_to_mono_smoke, run_resampler_expected_count_smoke, run_resampler_invalid_rate_smoke, run_resampler_linear_smoke
from miniaudio_sound import run_sound_control_smoke, run_sound_pause_smoke, run_sound_progress_smoke, run_sound_seek_smoke, run_sound_spatial_scene_smoke, run_sound_spatial_smoke
from miniaudio_sound_group import run_sound_group_attenuation_boundary_smoke, run_sound_group_attenuation_controls_smoke, run_sound_group_control_smoke, run_sound_group_extended_controls_smoke, run_sound_group_fade_invalid_smoke, run_sound_group_fade_smoke, run_sound_group_invalid_state_smoke, run_sound_group_spatial_controls_smoke
from miniaudio_spatializer import run_spatializer_invalid_args_smoke, run_spatializer_smoke
from miniaudio_sync_primitives import run_sync_primitives_invalid_args_smoke, run_sync_primitives_smoke
from miniaudio_waveform import run_waveform_handle_invalid_smoke, run_waveform_invalid_args_smoke, run_waveform_sine_smoke
from std.os.env import getenv


def main() raises:
    var skip_base_playback_smoke = getenv("MINIAUDIO_SKIP_BASE_PLAYBACK_SMOKE")
    if skip_base_playback_smoke == "":
        run_playback_smoke()
    else:
        print("Skipping baseline playback smoke")

    var context_smoke = getenv("MINIAUDIO_CONTEXT_SMOKE")
    if context_smoke != "":
        print("Running context smoke")
        run_context_smoke()

    var mojo_binding_contract_smoke = getenv("MINIAUDIO_BINDING_CONTRACT_SMOKE")
    if mojo_binding_contract_smoke != "":
        print("Running Mojo binding contract smoke")
        run_mojo_binding_contract_smoke()

    var mojo_handle_lifecycle_contract_smoke = getenv("MINIAUDIO_HANDLE_LIFECYCLE_CONTRACT_SMOKE")
    if mojo_handle_lifecycle_contract_smoke != "":
        print("Running Mojo handle lifecycle contract smoke")
        run_mojo_handle_lifecycle_contract_smoke()

    var mojo_device_init_ex_contract_suite = getenv("MINIAUDIO_DEVICE_INIT_EX_CONTRACT_SUITE")
    if mojo_device_init_ex_contract_suite != "":
        print("Running Mojo device init_ex contract suite")
        run_mojo_device_init_ex_contract_suite()

    var mojo_decoder_encoder_contract_suite = getenv("MINIAUDIO_DECODER_ENCODER_CONTRACT_SUITE")
    if mojo_decoder_encoder_contract_suite != "":
        print("Running Mojo decoder/encoder contract suite")
        run_mojo_decoder_encoder_contract_suite()

    var capture_smoke = getenv("MINIAUDIO_CAPTURE_SMOKE")
    if capture_smoke != "":
        print("Running capture smoke")
        run_capture_smoke()

    var capture_file = getenv("MINIAUDIO_CAPTURE_FILE")
    if capture_file != "":
        print("Running capture file smoke for:", capture_file)
        run_capture_file_smoke(capture_file)

    var encoder_wav_file = getenv("MINIAUDIO_ENCODER_WAV_FILE")
    if encoder_wav_file != "":
        print("Running encoder wav smoke for:", encoder_wav_file)
        run_encoder_wav_smoke(encoder_wav_file)

    var encoder_format_matrix_smoke = getenv("MINIAUDIO_ENCODER_FORMAT_MATRIX_SMOKE")
    if encoder_format_matrix_smoke != "":
        print("Running encoder wav format matrix smoke")
        run_encoder_wav_format_matrix_smoke("./build/test_assets/encoder_format_matrix.wav")

    var duplex_smoke = getenv("MINIAUDIO_DUPLEX_SMOKE")
    if duplex_smoke != "":
        print("Running duplex smoke")
        run_duplex_smoke()

    var duplex_control_smoke = getenv("MINIAUDIO_DUPLEX_CONTROL_SMOKE")
    if duplex_control_smoke != "":
        print("Running duplex control smoke")
        run_duplex_control_smoke()

    var devices_smoke = getenv("MINIAUDIO_DEVICES_SMOKE")
    if devices_smoke != "":
        print("Running devices smoke")
        run_devices_smoke()

    var device_select_smoke = getenv("MINIAUDIO_DEVICE_SELECT_SMOKE")
    if device_select_smoke != "":
        print("Running device select smoke")
        run_device_select_smoke()

    var device_control_smoke = getenv("MINIAUDIO_DEVICE_CONTROL_SMOKE")
    if device_control_smoke != "":
        print("Running device control smoke")
        run_device_control_smoke()

    var device_volume_smoke = getenv("MINIAUDIO_DEVICE_VOLUME_SMOKE")
    if device_volume_smoke != "":
        print("Running device volume smoke")
        run_device_volume_smoke()

    var device_config_smoke = getenv("MINIAUDIO_DEVICE_CONFIG_SMOKE")
    if device_config_smoke != "":
        print("Running device config smoke")
        run_device_config_smoke()

    var device_format_matrix_smoke = getenv("MINIAUDIO_DEVICE_FORMAT_MATRIX_SMOKE")
    if device_format_matrix_smoke != "":
        print("Running device format matrix smoke")
        run_device_format_matrix_smoke()

    var device_init_ex_smoke = getenv("MINIAUDIO_DEVICE_INIT_EX_SMOKE")
    if device_init_ex_smoke != "":
        print("Running device init_ex smoke")
        run_device_init_ex_smoke()

    var device_callback_smoke = getenv("MINIAUDIO_DEVICE_CALLBACK_SMOKE")
    if device_callback_smoke != "":
        print("Running device callback smoke")
        run_device_callback_smoke()

    var device_callback_longrun_smoke = getenv("MINIAUDIO_DEVICE_CALLBACK_LONGRUN_SMOKE")
    if device_callback_longrun_smoke != "":
        var longrun_ms_env = getenv("MINIAUDIO_DEVICE_CALLBACK_LONGRUN_MS")
        var longrun_duration_ms = UInt32(600000)
        if longrun_ms_env == "30000":
            longrun_duration_ms = UInt32(30000)
        elif longrun_ms_env == "60000":
            longrun_duration_ms = UInt32(60000)
        elif longrun_ms_env == "120000":
            longrun_duration_ms = UInt32(120000)
        elif longrun_ms_env == "600000":
            longrun_duration_ms = UInt32(600000)

        print("Running device callback longrun smoke for ms:", longrun_duration_ms)
        run_device_callback_longrun_smoke(longrun_duration_ms)

    var decoder_file = getenv("MINIAUDIO_DECODER_FILE")
    if decoder_file != "":
        print("Running decoder smoke for:", decoder_file)
        run_decoder_smoke(decoder_file)

    var decoder_read_file = getenv("MINIAUDIO_DECODER_READ_FILE")
    if decoder_read_file != "":
        print("Running decoder read smoke for:", decoder_read_file)
        run_decoder_read_smoke(decoder_read_file)

    var decoder_vfs_file = getenv("MINIAUDIO_DECODER_VFS_FILE")
    if decoder_vfs_file != "":
        print("Running decoder VFS smoke for:", decoder_vfs_file)
        run_decoder_vfs_smoke(decoder_vfs_file)

    var decoder_format_matrix_file = getenv("MINIAUDIO_DECODER_FORMAT_MATRIX_FILE")
    if decoder_format_matrix_file != "":
        print("Running decoder output format matrix smoke for:", decoder_format_matrix_file)
        run_decoder_output_format_matrix_smoke(decoder_format_matrix_file)

    var decoder_memory_smoke = getenv("MINIAUDIO_DECODER_MEMORY_SMOKE")
    if decoder_memory_smoke != "":
        print("Running decoder memory smoke")
        run_decoder_memory_smoke()

    var decoder_memory_format_matrix_smoke = getenv("MINIAUDIO_DECODER_MEMORY_FORMAT_MATRIX_SMOKE")
    if decoder_memory_format_matrix_smoke != "":
        print("Running decoder memory output format matrix smoke")
        run_decoder_memory_output_format_matrix_smoke()

    var decoder_memory_invalid_args_smoke = getenv("MINIAUDIO_DECODER_MEMORY_INVALID_ARGS_SMOKE")
    if decoder_memory_invalid_args_smoke != "":
        print("Running decoder memory invalid-args smoke")
        run_decoder_memory_invalid_args_smoke()

    var encoder_write_frames_input = getenv("MINIAUDIO_ENCODER_WRITE_FRAMES_INPUT")
    var encoder_write_frames_output = getenv("MINIAUDIO_ENCODER_WRITE_FRAMES_OUTPUT")
    if encoder_write_frames_input != "" and encoder_write_frames_output != "":
        print("Running encoder write_pcm_frames smoke from:", encoder_write_frames_input, "to:", encoder_write_frames_output)
        run_encoder_write_frames_smoke(encoder_write_frames_input, encoder_write_frames_output)

    var encoder_invalid_state_smoke = getenv("MINIAUDIO_ENCODER_INVALID_STATE_SMOKE")
    if encoder_invalid_state_smoke != "":
        print("Running encoder invalid-state smoke")
        run_encoder_invalid_state_smoke()

    var encoder_vfs_wav_file = getenv("MINIAUDIO_ENCODER_VFS_WAV_FILE")
    if encoder_vfs_wav_file != "":
        print("Running encoder VFS WAV smoke for:", encoder_vfs_wav_file)
        run_encoder_vfs_wav_smoke(encoder_vfs_wav_file)

    var playback_file = getenv("MINIAUDIO_PLAYBACK_FILE")
    if playback_file != "":
        print("Running playback file smoke for:", playback_file)
        run_playback_file_smoke(playback_file)

    var engine_play_file = getenv("MINIAUDIO_ENGINE_PLAY_FILE")
    if engine_play_file != "":
        print("Running engine play sound smoke for:", engine_play_file)
        run_engine_play_sound_smoke(engine_play_file)

    var engine_listener_smoke = getenv("MINIAUDIO_ENGINE_LISTENER_SMOKE")
    if engine_listener_smoke != "":
        print("Running engine listener control smoke")
        run_engine_listener_control_smoke()

    var sound_file = getenv("MINIAUDIO_SOUND_FILE")
    if sound_file != "":
        print("Running sound control smoke for:", sound_file)
        run_sound_control_smoke(sound_file)

    var sound_spatial_file = getenv("MINIAUDIO_SOUND_SPATIAL_FILE")
    if sound_spatial_file != "":
        print("Running sound spatial control smoke for:", sound_spatial_file)
        run_sound_spatial_smoke(sound_spatial_file)

    var sound_progress_file = getenv("MINIAUDIO_SOUND_PROGRESS_FILE")
    if sound_progress_file != "":
        print("Running sound progress smoke for:", sound_progress_file)
        run_sound_progress_smoke(sound_progress_file)

    var sound_seek_file = getenv("MINIAUDIO_SOUND_SEEK_FILE")
    if sound_seek_file != "":
        print("Running sound seek smoke for:", sound_seek_file)
        run_sound_seek_smoke(sound_seek_file)

    var sound_pause_file = getenv("MINIAUDIO_SOUND_PAUSE_FILE")
    if sound_pause_file != "":
        print("Running sound pause smoke for:", sound_pause_file)
        run_sound_pause_smoke(sound_pause_file)

    var sound_group_file = getenv("MINIAUDIO_SOUND_GROUP_FILE")
    if sound_group_file != "":
        print("Running sound group control smoke for:", sound_group_file)
        run_sound_group_control_smoke(sound_group_file)

    var sound_group_extended_file = getenv("MINIAUDIO_SOUND_GROUP_EXTENDED_FILE")
    if sound_group_extended_file != "":
        print("Running sound group extended controls smoke for:", sound_group_extended_file)
        run_sound_group_extended_controls_smoke(sound_group_extended_file)

    var sound_group_invalid_smoke = getenv("MINIAUDIO_SOUND_GROUP_INVALID_SMOKE")
    if sound_group_invalid_smoke != "":
        print("Running sound group invalid-state smoke")
        run_sound_group_invalid_state_smoke()

    var sound_group_spatial_file = getenv("MINIAUDIO_SOUND_GROUP_SPATIAL_FILE")
    if sound_group_spatial_file != "":
        print("Running sound group spatial controls smoke for:", sound_group_spatial_file)
        run_sound_group_spatial_controls_smoke(sound_group_spatial_file)

    var sound_group_attenuation_file = getenv("MINIAUDIO_SOUND_GROUP_ATTENUATION_FILE")
    if sound_group_attenuation_file != "":
        print("Running sound group attenuation controls smoke for:", sound_group_attenuation_file)
        run_sound_group_attenuation_controls_smoke(sound_group_attenuation_file)

    var sound_group_attenuation_boundary_smoke = getenv("MINIAUDIO_SOUND_GROUP_ATTENUATION_BOUNDARY_SMOKE")
    if sound_group_attenuation_boundary_smoke != "":
        print("Running sound group attenuation boundary smoke")
        run_sound_group_attenuation_boundary_smoke()

    var sound_group_fade_file = getenv("MINIAUDIO_SOUND_GROUP_FADE_FILE")
    if sound_group_fade_file != "":
        print("Running sound group fade smoke for:", sound_group_fade_file)
        run_sound_group_fade_smoke(sound_group_fade_file)

    var sound_group_fade_invalid_smoke = getenv("MINIAUDIO_SOUND_GROUP_FADE_INVALID_SMOKE")
    if sound_group_fade_invalid_smoke != "":
        print("Running sound group fade invalid smoke")
        run_sound_group_fade_invalid_smoke()

    var data_source_extended_file = getenv("MINIAUDIO_DATA_SOURCE_EXTENDED_FILE")
    if data_source_extended_file != "":
        print("Running data source extended smoke for:", data_source_extended_file)
        run_data_source_extended_smoke(data_source_extended_file)

    var data_source_range_file = getenv("MINIAUDIO_DATA_SOURCE_RANGE_FILE")
    if data_source_range_file != "":
        print("Running data source range smoke for:", data_source_range_file)
        run_data_source_range_smoke(data_source_range_file)

    var data_source_invalid_smoke = getenv("MINIAUDIO_DATA_SOURCE_INVALID_SMOKE")
    if data_source_invalid_smoke != "":
        print("Running data source invalid smoke")
        run_data_source_invalid_smoke()

    var data_source_loop_point_file = getenv("MINIAUDIO_DATA_SOURCE_LOOP_POINT_FILE")
    if data_source_loop_point_file != "":
        print("Running data source loop point smoke for:", data_source_loop_point_file)
        run_data_source_loop_point_smoke(data_source_loop_point_file)

    var eq_nodes_notch_smoke = getenv("MINIAUDIO_NOTCH_NODE_SMOKE")
    if eq_nodes_notch_smoke != "":
        print("Running notch node smoke")
        run_notch_node_smoke()

    var eq_nodes_peak_smoke = getenv("MINIAUDIO_PEAK_NODE_SMOKE")
    if eq_nodes_peak_smoke != "":
        print("Running peak node smoke")
        run_peak_node_smoke()

    var eq_nodes_loshelf_smoke = getenv("MINIAUDIO_LOSHELF_NODE_SMOKE")
    if eq_nodes_loshelf_smoke != "":
        print("Running loshelf node smoke")
        run_loshelf_node_smoke()

    var eq_nodes_hishelf_smoke = getenv("MINIAUDIO_HISHELF_NODE_SMOKE")
    if eq_nodes_hishelf_smoke != "":
        print("Running hishelf node smoke")
        run_hishelf_node_smoke()

    var eq_nodes_invalid_smoke = getenv("MINIAUDIO_EQ_NODES_INVALID_SMOKE")
    if eq_nodes_invalid_smoke != "":
        print("Running EQ nodes invalid smoke")
        run_eq_nodes_invalid_smoke()

    var spatial_scene_file = getenv("MINIAUDIO_SPATIAL_SCENE_FILE")
    if spatial_scene_file != "":
        print("Running sound spatial scene smoke for:", spatial_scene_file)
        run_sound_spatial_scene_smoke(spatial_scene_file)

    var node_attach_file = getenv("MINIAUDIO_NODE_ATTACH_FILE")
    if node_attach_file != "":
        print("Running node attach/detach smoke for:", node_attach_file)
        run_node_attach_detach_smoke(node_attach_file)

    var node_routing_file = getenv("MINIAUDIO_NODE_ROUTING_FILE")
    if node_routing_file != "":
        print("Running node routing scene smoke for:", node_routing_file)
        run_node_routing_scene_smoke(node_routing_file)

    var lpf_node_file = getenv("MINIAUDIO_LPF_NODE_FILE")
    if lpf_node_file != "":
        print("Running lpf node smoke for:", lpf_node_file)
        run_lpf_node_smoke(lpf_node_file)

    var hpf_node_file = getenv("MINIAUDIO_HPF_NODE_FILE")
    if hpf_node_file != "":
        print("Running hpf node smoke for:", hpf_node_file)
        run_hpf_node_smoke(hpf_node_file)

    var reverb_like_chain_file = getenv("MINIAUDIO_REVERB_LIKE_CHAIN_FILE")
    if reverb_like_chain_file != "":
        print("Running reverb-like chain smoke for:", reverb_like_chain_file)
        run_reverb_like_chain_smoke(reverb_like_chain_file)

    var splitter_file = getenv("MINIAUDIO_SPLITTER_FILE")
    if splitter_file != "":
        print("Running splitter dry/wet smoke for:", splitter_file)
        run_splitter_dry_wet_smoke(splitter_file)

    var resource_file = getenv("MINIAUDIO_RESOURCE_FILE")
    if resource_file != "":
        print("Running resource manager smoke for:", resource_file)
        run_resource_manager_smoke(resource_file)

    var resource_async_file = getenv("MINIAUDIO_RESOURCE_ASYNC_FILE")
    if resource_async_file != "":
        print("Running resource manager async poll smoke for:", resource_async_file)
        run_resource_manager_async_poll_smoke(resource_async_file)

    var resource_stream_async_file = getenv("MINIAUDIO_RESOURCE_STREAM_ASYNC_FILE")
    if resource_stream_async_file != "":
        print("Running resource manager streaming async smoke for:", resource_stream_async_file)
        run_resource_manager_streaming_async_smoke(resource_stream_async_file)

    var resource_init_ex_file = getenv("MINIAUDIO_RESOURCE_INIT_EX_FILE")
    if resource_init_ex_file != "":
        print("Running resource manager init_ex smoke for:", resource_init_ex_file)
        run_resource_manager_init_ex_smoke(resource_init_ex_file)

    var resource_init_ex_w_file = getenv("MINIAUDIO_RESOURCE_INIT_EX_W_FILE")
    if resource_init_ex_w_file != "":
        print("Running resource manager init_ex_w smoke for:", resource_init_ex_w_file)
        run_resource_manager_init_ex_w_smoke(resource_init_ex_w_file)

    var resource_init_copy_file = getenv("MINIAUDIO_RESOURCE_INIT_COPY_FILE")
    if resource_init_copy_file != "":
        print("Running resource manager init_copy smoke for:", resource_init_copy_file)
        run_resource_manager_init_copy_smoke(resource_init_copy_file)

    var resource_init_w_file = getenv("MINIAUDIO_RESOURCE_INIT_W_FILE")
    if resource_init_w_file != "":
        print("Running resource manager init_w smoke for:", resource_init_w_file)
        run_resource_manager_init_w_smoke(resource_init_w_file)

    var resource_pipeline_notifications_file = getenv("MINIAUDIO_RESOURCE_PIPELINE_NOTIFICATIONS_FILE")
    if resource_pipeline_notifications_file != "":
        print("Running resource manager pipeline notifications smoke for:", resource_pipeline_notifications_file)
        run_resource_manager_pipeline_notification_smoke(resource_pipeline_notifications_file)

    var resource_pipeline_notifications_w_file = getenv("MINIAUDIO_RESOURCE_PIPELINE_NOTIFICATIONS_W_FILE")
    if resource_pipeline_notifications_w_file != "":
        print("Running resource manager pipeline notifications_w smoke for:", resource_pipeline_notifications_w_file)
        run_resource_manager_pipeline_notification_w_smoke(resource_pipeline_notifications_w_file)

    var resource_pipeline_fence_file = getenv("MINIAUDIO_RESOURCE_PIPELINE_FENCE_FILE")
    if resource_pipeline_fence_file != "":
        print("Running resource manager pipeline fence smoke for:", resource_pipeline_fence_file)
        run_resource_manager_pipeline_fence_smoke(resource_pipeline_fence_file)

    var resource_pipeline_notifications_fences_file = getenv("MINIAUDIO_RESOURCE_PIPELINE_NOTIFICATIONS_FENCES_FILE")
    if resource_pipeline_notifications_fences_file != "":
        print("Running resource manager pipeline notifications+fences smoke for:", resource_pipeline_notifications_fences_file)
        run_resource_manager_pipeline_notifications_and_fences_smoke(resource_pipeline_notifications_fences_file)

    var resource_pipeline_notifications_fences_w_file = getenv("MINIAUDIO_RESOURCE_PIPELINE_NOTIFICATIONS_FENCES_W_FILE")
    if resource_pipeline_notifications_fences_w_file != "":
        print("Running resource manager pipeline notifications+fences_w smoke for:", resource_pipeline_notifications_fences_w_file)
        run_resource_manager_pipeline_notifications_and_fences_w_smoke(resource_pipeline_notifications_fences_w_file)

    var job_queue_smoke = getenv("MINIAUDIO_JOB_QUEUE_SMOKE")
    if job_queue_smoke != "":
        print("Running job queue smoke")
        run_job_queue_smoke()

    var job_queue_invalid_args_smoke = getenv("MINIAUDIO_JOB_QUEUE_INVALID_ARGS_SMOKE")
    if job_queue_invalid_args_smoke != "":
        print("Running job queue invalid-args smoke")
        run_job_queue_invalid_args_smoke()

    var sync_primitives_smoke = getenv("MINIAUDIO_SYNC_PRIMITIVES_SMOKE")
    if sync_primitives_smoke != "":
        print("Running sync primitives smoke")
        run_sync_primitives_smoke()

    var sync_primitives_invalid_args_smoke = getenv("MINIAUDIO_SYNC_PRIMITIVES_INVALID_ARGS_SMOKE")
    if sync_primitives_invalid_args_smoke != "":
        print("Running sync primitives invalid-args smoke")
        run_sync_primitives_invalid_args_smoke()

    var async_notification_poll_smoke = getenv("MINIAUDIO_ASYNC_NOTIFICATION_POLL_SMOKE")
    if async_notification_poll_smoke != "":
        print("Running async notification poll smoke")
        run_async_notification_poll_smoke()

    var async_notification_poll_invalid_args_smoke = getenv("MINIAUDIO_ASYNC_NOTIFICATION_POLL_INVALID_ARGS_SMOKE")
    if async_notification_poll_invalid_args_smoke != "":
        print("Running async notification poll invalid-args smoke")
        run_async_notification_poll_invalid_args_smoke()

    var async_notification_event_smoke = getenv("MINIAUDIO_ASYNC_NOTIFICATION_EVENT_SMOKE")
    if async_notification_event_smoke != "":
        print("Running async notification event smoke")
        run_async_notification_event_smoke()

    var async_notification_event_invalid_args_smoke = getenv("MINIAUDIO_ASYNC_NOTIFICATION_EVENT_INVALID_ARGS_SMOKE")
    if async_notification_event_invalid_args_smoke != "":
        print("Running async notification event invalid-args smoke")
        run_async_notification_event_invalid_args_smoke()

    var custom_buffer_data_source_smoke = getenv("MINIAUDIO_CUSTOM_BUFFER_DATA_SOURCE_SMOKE")
    if custom_buffer_data_source_smoke != "":
        print("Running custom buffer data source smoke")
        run_custom_buffer_data_source_smoke()

    var custom_buffer_data_source_invalid_args_smoke = getenv("MINIAUDIO_CUSTOM_BUFFER_DATA_SOURCE_INVALID_ARGS_SMOKE")
    if custom_buffer_data_source_invalid_args_smoke != "":
        print("Running custom buffer data source invalid-args smoke")
        run_custom_buffer_data_source_invalid_args_smoke()

    var logging_smoke = getenv("MINIAUDIO_LOGGING_SMOKE")
    if logging_smoke != "":
        print("Running logging smoke")
        run_logging_smoke()

    var logging_invalid_smoke = getenv("MINIAUDIO_LOGGING_INVALID_SMOKE")
    if logging_invalid_smoke != "":
        print("Running logging invalid-state smoke")
        run_logging_invalid_state_smoke()

    var device_user_callback_smoke = getenv("MINIAUDIO_DEVICE_USER_CALLBACK_SMOKE")
    if device_user_callback_smoke != "":
        print("Running device user callback smoke")
        run_device_user_callback_smoke()

    var biquad_peaking_eq_smoke = getenv("MINIAUDIO_BIQUAD_PEAKING_EQ_SMOKE")
    if biquad_peaking_eq_smoke != "":
        print("Running biquad peaking EQ smoke")
        run_biquad_peaking_eq_smoke()

    var biquad_invalid_q_smoke = getenv("MINIAUDIO_BIQUAD_INVALID_Q_SMOKE")
    if biquad_invalid_q_smoke != "":
        print("Running biquad invalid q smoke")
        run_biquad_invalid_q_smoke()

    var resampler_linear_smoke = getenv("MINIAUDIO_RESAMPLER_LINEAR_SMOKE")
    if resampler_linear_smoke != "":
        print("Running resampler linear smoke")
        run_resampler_linear_smoke()

    var resampler_invalid_rate_smoke = getenv("MINIAUDIO_RESAMPLER_INVALID_RATE_SMOKE")
    if resampler_invalid_rate_smoke != "":
        print("Running resampler invalid-rate smoke")
        run_resampler_invalid_rate_smoke()

    var resampler_expected_count_smoke = getenv("MINIAUDIO_RESAMPLER_EXPECTED_COUNT_SMOKE")
    if resampler_expected_count_smoke != "":
        print("Running resampler expected-count smoke")
        run_resampler_expected_count_smoke()

    var channel_converter_stereo_mono_smoke = getenv("MINIAUDIO_CHANNEL_CONVERTER_STEREO_MONO_SMOKE")
    if channel_converter_stereo_mono_smoke != "":
        print("Running channel converter stereo-to-mono smoke")
        run_channel_converter_stereo_to_mono_smoke()

    var channel_converter_invalid_channels_smoke = getenv("MINIAUDIO_CHANNEL_CONVERTER_INVALID_CHANNELS_SMOKE")
    if channel_converter_invalid_channels_smoke != "":
        print("Running channel converter invalid-channels smoke")
        run_channel_converter_invalid_channels_smoke()

    var channel_converter_init_mode_smoke = getenv("MINIAUDIO_CHANNEL_CONVERTER_INIT_MODE_SMOKE")
    if channel_converter_init_mode_smoke != "":
        print("Running channel converter init-mode smoke")
        run_channel_converter_init_mode_smoke()

    var data_converter_smoke = getenv("MINIAUDIO_DATA_CONVERTER_SMOKE")
    if data_converter_smoke != "":
        print("Running data converter smoke")
        run_data_converter_smoke()

    var data_converter_invalid_args_smoke = getenv("MINIAUDIO_DATA_CONVERTER_INVALID_ARGS_SMOKE")
    if data_converter_invalid_args_smoke != "":
        print("Running data converter invalid-args smoke")
        run_data_converter_invalid_args_smoke()

    var waveform_sine_smoke = getenv("MINIAUDIO_WAVEFORM_SINE_SMOKE")
    if waveform_sine_smoke != "":
        print("Running waveform sine smoke")
        run_waveform_sine_smoke()

    var waveform_invalid_args_smoke = getenv("MINIAUDIO_WAVEFORM_INVALID_ARGS_SMOKE")
    if waveform_invalid_args_smoke != "":
        print("Running waveform invalid-args smoke")
        run_waveform_invalid_args_smoke()

    var waveform_handle_invalid_smoke = getenv("MINIAUDIO_WAVEFORM_HANDLE_INVALID_SMOKE")
    if waveform_handle_invalid_smoke != "":
        print("Running waveform handle invalid smoke")
        run_waveform_handle_invalid_smoke()

    var noise_smoke = getenv("MINIAUDIO_NOISE_SMOKE")
    if noise_smoke != "":
        print("Running noise smoke")
        run_noise_smoke()

    var noise_invalid_args_smoke = getenv("MINIAUDIO_NOISE_INVALID_ARGS_SMOKE")
    if noise_invalid_args_smoke != "":
        print("Running noise invalid-args smoke")
        run_noise_invalid_args_smoke()

    var spatializer_smoke = getenv("MINIAUDIO_SPATIALIZER_SMOKE")
    if spatializer_smoke != "":
        print("Running standalone spatializer smoke")
        run_spatializer_smoke()

    var spatializer_invalid_args_smoke = getenv("MINIAUDIO_SPATIALIZER_INVALID_ARGS_SMOKE")
    if spatializer_invalid_args_smoke != "":
        print("Running standalone spatializer invalid-args smoke")
        run_spatializer_invalid_args_smoke()

    var pcm_rb_smoke = getenv("MINIAUDIO_PCM_RB_SMOKE")
    if pcm_rb_smoke != "":
        print("Running pcm ring buffer smoke")
        run_pcm_rb_smoke()

    var pcm_rb_overflow_smoke = getenv("MINIAUDIO_PCM_RB_OVERFLOW_SMOKE")
    if pcm_rb_overflow_smoke != "":
        print("Running pcm ring buffer overflow smoke")
        run_pcm_rb_overflow_smoke()

    var pcm_rb_invalid_args_smoke = getenv("MINIAUDIO_PCM_RB_INVALID_ARGS_SMOKE")
    if pcm_rb_invalid_args_smoke != "":
        print("Running pcm ring buffer invalid-args smoke")
        run_pcm_rb_invalid_args_smoke()

    var pcm_rb_handle_smoke = getenv("MINIAUDIO_PCM_RB_HANDLE_SMOKE")
    if pcm_rb_handle_smoke != "":
        print("Running pcm ring buffer handle smoke")
        run_pcm_rb_handle_smoke()
