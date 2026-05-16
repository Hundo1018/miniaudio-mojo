"""High-level API for memory-based I/O (playback from buffer, capture to buffer)."""

from std.ffi import OwnedDLHandle
from miniaudio_ctypes import MiniAudioCtypes
from miniaudio_errors import *
from miniaudio_result_utils import *


struct PlaybackFromBuffer:
    """
    Play audio from a pre-allocated float buffer.
    
    Usage:
    ```
    var playback = PlaybackFromBuffer()
    playback.init(ctypes, sample_rate, channels, buffer_ptr, frame_count)
    playback.start()
    # Wait for playback to finish...
    playback.stop()
    playback.destroy()
    ```
    """
    var _ctypes: MiniAudioCtypes
    var _handle: OpaquePointer[MutExternalOrigin]
    var _initialized: Bool

    def __init__(out self, ctypes: MiniAudioCtypes):
        self._ctypes = ctypes
        self._handle = self._ctypes.playback_from_buffer_create()
        self._initialized = True

    def init(
        self,
        sample_rate: UInt32,
        channels: UInt32,
        buffer_ptr: UnsafePointer[Float32],
        frame_count: UInt64,
    ) raises -> Int:
        """
        Initialize playback from a buffer.
        
        Args:
            sample_rate: Sample rate in Hz (e.g., 44100, 48000)
            channels: Number of audio channels (1=mono, 2=stereo, etc.)
            buffer_ptr: Pointer to float buffer containing audio samples
            frame_count: Number of frames in the buffer (samples per channel)
        
        Returns:
            0 on success, error code on failure
        """
        if not self._initialized:
            raise Error("PlaybackFromBuffer not initialized")
        
        var result = self._ctypes.playback_from_buffer_init_f32(
            self._handle, sample_rate, channels, buffer_ptr, frame_count
        )
        
        if result != 0:
            raise Error(
                "playback_from_buffer_init_f32 failed: "
                + self._ctypes.result_description(result)
            )
        
        return result

    def start(self) raises -> Int:
        """Start playback."""
        if not self._initialized:
            raise Error("PlaybackFromBuffer not initialized")
        
        var result = self._ctypes.playback_from_buffer_start(self._handle)
        if result != 0:
            raise Error(
                "playback_from_buffer_start failed: "
                + self._ctypes.result_description(result)
            )
        return result

    def stop(self) raises -> Int:
        """Stop playback."""
        if not self._initialized:
            raise Error("PlaybackFromBuffer not initialized")
        
        var result = self._ctypes.playback_from_buffer_stop(self._handle)
        if result != 0:
            raise Error(
                "playback_from_buffer_stop failed: "
                + self._ctypes.result_description(result)
            )
        return result

    def is_finished(self) raises -> Bool:
        """Check if playback has reached the end of the buffer."""
        if not self._initialized:
            raise Error("PlaybackFromBuffer not initialized")
        
        var result = self._ctypes.playback_from_buffer_is_finished(self._handle)
        return result != 0

    def get_position_in_frames(self) raises -> UInt64:
        """Get the current playback position in frames."""
        if not self._initialized:
            raise Error("PlaybackFromBuffer not initialized")
        
        var result = self._ctypes.playback_from_buffer_get_position_in_frames(self._handle)
        if result < 0:
            raise Error(
                "playback_from_buffer_get_position_in_frames failed: error code "
                + String(result)
            )
        return UInt64(result)

    def uninit(self) raises -> Int:
        """Uninitialize the playback handle."""
        if not self._initialized:
            return 0
        
        var result = self._ctypes.playback_from_buffer_uninit(self._handle)
        if result != 0:
            raise Error(
                "playback_from_buffer_uninit failed: "
                + self._ctypes.result_description(result)
            )
        return result

    def destroy(self):
        """Destroy the playback handle and free resources."""
        if self._initialized:
            self._ctypes.playback_from_buffer_destroy(self._handle)
            self._initialized = False

    def __del__(owned self):
        """Cleanup on deletion."""
        if self._initialized:
            self._ctypes.playback_from_buffer_destroy(self._handle)


struct CaptureToBuffer:
    """
    Capture audio to a pre-allocated float buffer.
    
    Usage:
    ```
    var capture = CaptureToBuffer()
    capture.init(ctypes, sample_rate, channels, buffer_ptr, capacity)
    capture.start()
    # Let capture run for some time...
    capture.stop()
    var frames_captured = capture.get_frames_captured()
    capture.destroy()
    ```
    """
    var _ctypes: MiniAudioCtypes
    var _handle: OpaquePointer[MutExternalOrigin]
    var _initialized: Bool

    def __init__(out self, ctypes: MiniAudioCtypes):
        self._ctypes = ctypes
        self._handle = self._ctypes.capture_to_buffer_create()
        self._initialized = True

    def init(
        self,
        sample_rate: UInt32,
        channels: UInt32,
        buffer_ptr: UnsafePointer[Float32],
        buffer_capacity: UInt64,
    ) raises -> Int:
        """
        Initialize capture to a buffer.
        
        Args:
            sample_rate: Sample rate in Hz (e.g., 44100, 48000)
            channels: Number of audio channels (1=mono, 2=stereo, etc.)
            buffer_ptr: Pointer to float buffer where audio will be stored
            buffer_capacity: Maximum number of frames the buffer can hold
        
        Returns:
            0 on success, error code on failure
        """
        if not self._initialized:
            raise Error("CaptureToBuffer not initialized")
        
        var result = self._ctypes.capture_to_buffer_init_f32(
            self._handle, sample_rate, channels, buffer_ptr, buffer_capacity
        )
        
        if result != 0:
            raise Error(
                "capture_to_buffer_init_f32 failed: "
                + self._ctypes.result_description(result)
            )
        
        return result

    def start(self) raises -> Int:
        """Start capture."""
        if not self._initialized:
            raise Error("CaptureToBuffer not initialized")
        
        var result = self._ctypes.capture_to_buffer_start(self._handle)
        if result != 0:
            raise Error(
                "capture_to_buffer_start failed: "
                + self._ctypes.result_description(result)
            )
        return result

    def stop(self) raises -> Int:
        """Stop capture."""
        if not self._initialized:
            raise Error("CaptureToBuffer not initialized")
        
        var result = self._ctypes.capture_to_buffer_stop(self._handle)
        if result != 0:
            raise Error(
                "capture_to_buffer_stop failed: "
                + self._ctypes.result_description(result)
            )
        return result

    def get_frames_captured(self) raises -> UInt64:
        """Get the number of frames captured so far."""
        if not self._initialized:
            raise Error("CaptureToBuffer not initialized")
        
        var result = self._ctypes.capture_to_buffer_get_frames_captured(self._handle)
        if result < 0:
            raise Error(
                "capture_to_buffer_get_frames_captured failed: error code "
                + String(result)
            )
        return UInt64(result)

    def reset(self) raises -> Int:
        """Reset the capture position to 0."""
        if not self._initialized:
            raise Error("CaptureToBuffer not initialized")
        
        var result = self._ctypes.capture_to_buffer_reset(self._handle)
        if result != 0:
            raise Error(
                "capture_to_buffer_reset failed: "
                + self._ctypes.result_description(result)
            )
        return result

    def uninit(self) raises -> Int:
        """Uninitialize the capture handle."""
        if not self._initialized:
            return 0
        
        var result = self._ctypes.capture_to_buffer_uninit(self._handle)
        if result != 0:
            raise Error(
                "capture_to_buffer_uninit failed: "
                + self._ctypes.result_description(result)
            )
        return result

    def destroy(self):
        """Destroy the capture handle and free resources."""
        if self._initialized:
            self._ctypes.capture_to_buffer_destroy(self._handle)
            self._initialized = False

    def __del__(owned self):
        """Cleanup on deletion."""
        if self._initialized:
            self._ctypes.capture_to_buffer_destroy(self._handle)
