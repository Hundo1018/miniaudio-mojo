#include <stdio.h>

#include "miniaudio_shim.h"

int main(void) {
    int result;

    printf("miniaudio version: %s\n", mmj_miniaudio_version());
    printf("native playback smoke: 440Hz, 2 seconds\n");

    result = mmj_play_sine_f32(48000, 2, 440.0, 2.0, 0.15f);
    if (result != 0) {
        printf("failed: %s (%d)\n", mmj_result_description(result), result);
        return 1;
    }

    printf("ok\n");
    return 0;
}
