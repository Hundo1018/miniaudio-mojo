from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_handles import MiniAudioResourceDataSourceHandle, MiniAudioResourceManagerHandle
from miniaudio_errors import MA_SUCCESS
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
