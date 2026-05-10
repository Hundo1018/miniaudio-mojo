from std.python import Python


def main() raises:
    var ctypes = Python.import_module("ctypes")
    var lib = ctypes.CDLL("./build/libminiaudio_mojo.so")

    lib.mmj_miniaudio_version.restype = ctypes.c_char_p
    var version_bytes = lib.mmj_miniaudio_version()
    var version = String(py=version_bytes.decode("utf-8"))

    lib.mmj_play_sine_f32.argtypes = [
        ctypes.c_uint32,
        ctypes.c_uint32,
        ctypes.c_double,
        ctypes.c_double,
        ctypes.c_float,
    ]
    lib.mmj_play_sine_f32.restype = ctypes.c_int

    print("Mojo ctypes bridge -> miniaudio")
    print("miniaudio version:", version)

    var result = Int(py=lib.mmj_play_sine_f32(48000, 2, 440.0, 1.0, 0.15))
    if result != 0:
        lib.mmj_result_description.restype = ctypes.c_char_p
        var reason_bytes = lib.mmj_result_description(result)
        var reason = String(py=reason_bytes.decode("utf-8"))
        raise Error("playback failed: " + reason + " (" + String(result) + ")")

    print("playback ok")
