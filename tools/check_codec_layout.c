/*
 * Layout guard for the ma_wav / ma_flac / ma_mp3 shim handles.
 *
 * Those three structs are defined only inside miniaudio's implementation
 * section, so src/native/ma_shim_{wav,flac,mp3}.c cannot take sizeof() them and
 * embed fixed-size storage instead (MA_SHIM_*_STORAGE_BYTES). This translation
 * unit includes the implementation (with every MA_API function made static, so
 * nothing is exported or linked) purely to _Static_assert that the storage is
 * big enough and aligned enough. It is only ever compiled with -fsyntax-only:
 *
 *   pixi run check-codec-layout
 *
 * If this fails after a miniaudio upgrade, raise the matching constant in
 * src/native/ma_shim_<codec>.h.
 */
#define MA_API static
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include "ma_shim_flac.h"
#include "ma_shim_mp3.h"
#include "ma_shim_wav.h"

#include <stddef.h>

_Static_assert(sizeof(ma_wav) <= MA_SHIM_WAV_STORAGE_BYTES,
               "ma_wav outgrew MA_SHIM_WAV_STORAGE_BYTES (src/native/ma_shim_wav.h)");
_Static_assert(sizeof(ma_flac) <= MA_SHIM_FLAC_STORAGE_BYTES,
               "ma_flac outgrew MA_SHIM_FLAC_STORAGE_BYTES (src/native/ma_shim_flac.h)");
_Static_assert(sizeof(ma_mp3) <= MA_SHIM_MP3_STORAGE_BYTES,
               "ma_mp3 outgrew MA_SHIM_MP3_STORAGE_BYTES (src/native/ma_shim_mp3.h)");

_Static_assert(_Alignof(ma_wav) <= _Alignof(max_align_t), "ma_wav over-aligned for the shim storage");
_Static_assert(_Alignof(ma_flac) <= _Alignof(max_align_t), "ma_flac over-aligned for the shim storage");
_Static_assert(_Alignof(ma_mp3) <= _Alignof(max_align_t), "ma_mp3 over-aligned for the shim storage");
