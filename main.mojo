from miniaudio import run_playback_file_smoke, run_playback_smoke
from miniaudio_capture import run_capture_file_smoke, run_capture_smoke
from miniaudio_context import run_context_smoke
from miniaudio_decoder import run_decoder_read_smoke, run_decoder_smoke
from miniaudio_device import run_device_config_smoke, run_device_control_smoke, run_device_volume_smoke
from miniaudio_devices import run_devices_smoke
from miniaudio_duplex import run_duplex_control_smoke, run_duplex_smoke
from miniaudio_engine import run_engine_listener_control_smoke, run_engine_play_sound_smoke
from miniaudio_effects import run_lpf_node_smoke, run_reverb_like_chain_smoke
from miniaudio_node import run_node_attach_detach_smoke, run_node_routing_scene_smoke
from miniaudio_resource_manager import run_resource_manager_async_poll_smoke, run_resource_manager_smoke
from miniaudio_sound import run_sound_control_smoke, run_sound_spatial_scene_smoke, run_sound_spatial_smoke
from std.os.env import getenv


def main() raises:
    run_playback_smoke()

    var context_smoke = getenv("MINIAUDIO_CONTEXT_SMOKE")
    if context_smoke != "":
        print("Running context smoke")
        run_context_smoke()

    var capture_smoke = getenv("MINIAUDIO_CAPTURE_SMOKE")
    if capture_smoke != "":
        print("Running capture smoke")
        run_capture_smoke()

    var capture_file = getenv("MINIAUDIO_CAPTURE_FILE")
    if capture_file != "":
        print("Running capture file smoke for:", capture_file)
        run_capture_file_smoke(capture_file)

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

    var decoder_file = getenv("MINIAUDIO_DECODER_FILE")
    if decoder_file != "":
        print("Running decoder smoke for:", decoder_file)
        run_decoder_smoke(decoder_file)

    var decoder_read_file = getenv("MINIAUDIO_DECODER_READ_FILE")
    if decoder_read_file != "":
        print("Running decoder read smoke for:", decoder_read_file)
        run_decoder_read_smoke(decoder_read_file)

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

    var reverb_like_chain_file = getenv("MINIAUDIO_REVERB_LIKE_CHAIN_FILE")
    if reverb_like_chain_file != "":
        print("Running reverb-like chain smoke for:", reverb_like_chain_file)
        run_reverb_like_chain_smoke(reverb_like_chain_file)

    var resource_file = getenv("MINIAUDIO_RESOURCE_FILE")
    if resource_file != "":
        print("Running resource manager smoke for:", resource_file)
        run_resource_manager_smoke(resource_file)

    var resource_async_file = getenv("MINIAUDIO_RESOURCE_ASYNC_FILE")
    if resource_async_file != "":
        print("Running resource manager async poll smoke for:", resource_async_file)
        run_resource_manager_async_poll_smoke(resource_async_file)
