from ..ffi.miniaudio_ctypes import MiniAudioCtypes
from .miniaudio_result_utils import check_ma_result
from .miniaudio_errors import MA_SUCCESS, MA_INVALID_ARGS


struct DeviceWithUserCallback:
    """
    High-level wrapper for device with user-defined callbacks.
    
    This struct manages device lifecycle with user-provided audio processing callbacks.
    The user callback is responsible for processing audio frames in real-time.
    
    Note: Full callback support is still under development. Currently provides
    basic infrastructure for registering callback function pointers.
    
    Example usage:
        # In C code, define callback:
        # void my_callback(void* output, const void* input, 
        #                  uint32_t frame_count, void* user_data)
        # Then in Mojo:
        var device = DeviceWithUserCallback(ctypes, device_handle)
        device.set_callback(callback_ptr, user_context)
    """

    var _ctypes: MiniAudioCtypes
    var _device_handle: OpaquePointer[MutExternalOrigin]
    var _callback_ptr: OpaquePointer[MutExternalOrigin]
    var _user_data_ptr: OpaquePointer[MutExternalOrigin]
    var _initialized: Bool

    def __init__(
        out self,
        ctypes: MiniAudioCtypes,
        device_handle: OpaquePointer[MutExternalOrigin],
    ):
        """Initialize the user callback device wrapper."""
        self._ctypes = ctypes
        self._device_handle = device_handle
        self._callback_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)
        self._user_data_ptr = OpaquePointer[MutExternalOrigin](unsafe_from_address=0)
        self._initialized = True

    def set_callback(
        self,
        callback_ptr: OpaquePointer[MutExternalOrigin],
        user_data: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        """
        Register a user-defined data callback.
        
        Args:
            callback_ptr: Pointer to the callback function (mmj_device_data_callback)
            user_data: Pointer to user context data
            
        Returns:
            MA_SUCCESS on success, error code otherwise
        """
        if not self._initialized:
            return MA_INVALID_ARGS
        
        self._callback_ptr = callback_ptr
        self._user_data_ptr = user_data
        
        var result = self._ctypes.device_set_data_callback(
            self._device_handle,
            callback_ptr,
            user_data,
        )
        
        return result

    def set_stop_callback(
        self,
        callback_ptr: OpaquePointer[MutExternalOrigin],
        user_data: OpaquePointer[MutExternalOrigin],
    ) -> Int:
        """
        Register a user-defined stop callback.
        
        Args:
            callback_ptr: Pointer to the stop callback function
            user_data: Pointer to user context data
            
        Returns:
            MA_SUCCESS on success, error code otherwise
        """
        if not self._initialized:
            return MA_INVALID_ARGS
        
        return self._ctypes.device_set_stop_callback(
            self._device_handle,
            callback_ptr,
            user_data,
        )

    def clear_callbacks(self) -> Int:
        """Clear all registered callbacks."""
        if not self._initialized:
            return MA_INVALID_ARGS
        
        return self._ctypes.device_clear_callbacks(self._device_handle)

