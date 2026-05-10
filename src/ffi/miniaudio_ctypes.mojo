from std.python import Python, PythonObject


struct MiniAudioCtypes:
    var _ctypes: PythonObject
    var _lib: PythonObject

    def __init__(out self, lib_path: String) raises:
        self._ctypes = Python.import_module("ctypes")
        self._lib = self._ctypes.CDLL(lib_path)

        self._lib.mmj_miniaudio_version.restype = self._ctypes.c_char_p
        self._lib.mmj_result_description.restype = self._ctypes.c_char_p
        self._lib.mmj_play_sine_f32.argtypes = [
            self._ctypes.c_uint32,
            self._ctypes.c_uint32,
            self._ctypes.c_double,
            self._ctypes.c_double,
            self._ctypes.c_float,
        ]
        self._lib.mmj_play_sine_f32.restype = self._ctypes.c_int

    def version(self) raises -> String:
        var version_bytes = self._lib.mmj_miniaudio_version()
        return String(py=version_bytes.decode("utf-8"))

    def result_description(self, result: Int) raises -> String:
        var reason_bytes = self._lib.mmj_result_description(result)
        return String(py=reason_bytes.decode("utf-8"))

    def play_sine(
        self,
        sample_rate: UInt32,
        channels: UInt32,
        frequency_hz: Float64,
        duration_seconds: Float64,
        gain: Float32,
    ) raises -> Int:
        return Int(
            py=self._lib.mmj_play_sine_f32(
                sample_rate,
                channels,
                frequency_hz,
                duration_seconds,
                gain,
            )
        )
