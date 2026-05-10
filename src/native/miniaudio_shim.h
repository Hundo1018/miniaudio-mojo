#ifndef MINIAUDIO_MOJO_SHIM_H
#define MINIAUDIO_MOJO_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

const char* mmj_miniaudio_version(void);
const char* mmj_result_description(int result_code);
int mmj_play_sine_f32(
    uint32_t sample_rate,
    uint32_t channels,
    double frequency_hz,
    double duration_seconds,
    float gain
);

#ifdef __cplusplus
}
#endif

#endif
