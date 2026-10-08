#include "ma_shim_channel_map.h"
#include "miniaudio.h"

#include <string.h>

#define MA_SHIM_REQUIRE(cond) do { if (!(cond)) { return MA_INVALID_ARGS; } } while (0)

#define SHIM_STANDARD_MAP_LAST ((int)ma_standard_channel_map_sndio)

/* An input map is usable when it is NULL (the default map) or long enough. */
static int map_usable(const unsigned char* map, unsigned int map_len, unsigned int channels) {
    return map == NULL || map_len >= channels;
}

/* @binds ma_channel_map_init_blank */
int ma_shim_channel_map_init_blank(unsigned char* map, unsigned int map_cap, unsigned int channels) {
    MA_SHIM_REQUIRE(map != NULL && channels > 0 && map_cap >= channels);
    ma_channel_map_init_blank((ma_channel*)map, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_channel_map_init_standard */
int ma_shim_channel_map_init_standard(
    int standard, unsigned char* map, unsigned int map_cap, unsigned int channels
) {
    MA_SHIM_REQUIRE(standard >= 0 && standard <= SHIM_STANDARD_MAP_LAST);
    MA_SHIM_REQUIRE(map != NULL && map_cap > 0 && channels > 0);
    ma_channel_map_init_standard(
        (ma_standard_channel_map)standard, (ma_channel*)map, (size_t)map_cap, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_channel_map_copy */
int ma_shim_channel_map_copy(
    unsigned char* out, unsigned int out_cap,
    const unsigned char* in, unsigned int in_len, unsigned int channels
) {
    MA_SHIM_REQUIRE(out != NULL && in != NULL && channels > 0);
    MA_SHIM_REQUIRE(out_cap >= channels && in_len >= channels);
    ma_channel_map_copy((ma_channel*)out, (const ma_channel*)in, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_channel_map_copy_or_default */
int ma_shim_channel_map_copy_or_default(
    unsigned char* out, unsigned int out_cap,
    const unsigned char* in, unsigned int in_len, unsigned int channels
) {
    MA_SHIM_REQUIRE(out != NULL && out_cap > 0 && channels > 0);
    /* With an input map miniaudio copies `channels` entries and ignores the cap. */
    MA_SHIM_REQUIRE(in == NULL || (in_len >= channels && out_cap >= channels));
    ma_channel_map_copy_or_default(
        (ma_channel*)out, (size_t)out_cap, (const ma_channel*)in, (ma_uint32)channels);
    return MA_SUCCESS;
}

/* @binds ma_channel_map_get_channel */
int ma_shim_channel_map_get_channel(
    const unsigned char* map, unsigned int map_len,
    unsigned int channel_count, unsigned int channel_index, unsigned int* out_channel
) {
    if (out_channel != NULL) { *out_channel = 0; }
    MA_SHIM_REQUIRE(out_channel != NULL && map_usable(map, map_len, channel_count));
    *out_channel = (unsigned int)ma_channel_map_get_channel(
        (const ma_channel*)map, (ma_uint32)channel_count, (ma_uint32)channel_index);
    return MA_SUCCESS;
}

/* @binds ma_channel_map_is_valid */
int ma_shim_channel_map_is_valid(
    const unsigned char* map, unsigned int map_len, unsigned int channels, int* out_valid
) {
    if (out_valid != NULL) { *out_valid = 0; }
    MA_SHIM_REQUIRE(out_valid != NULL && map_usable(map, map_len, channels));
    *out_valid = ma_channel_map_is_valid((const ma_channel*)map, (ma_uint32)channels) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_channel_map_is_equal */
int ma_shim_channel_map_is_equal(
    const unsigned char* a, unsigned int a_len,
    const unsigned char* b, unsigned int b_len, unsigned int channels, int* out_equal
) {
    if (out_equal != NULL) { *out_equal = 0; }
    MA_SHIM_REQUIRE(out_equal != NULL);
    MA_SHIM_REQUIRE(map_usable(a, a_len, channels) && map_usable(b, b_len, channels));
    *out_equal = ma_channel_map_is_equal(
        (const ma_channel*)a, (const ma_channel*)b, (ma_uint32)channels) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_channel_map_is_blank */
int ma_shim_channel_map_is_blank(
    const unsigned char* map, unsigned int map_len, unsigned int channels, int* out_blank
) {
    if (out_blank != NULL) { *out_blank = 0; }
    MA_SHIM_REQUIRE(out_blank != NULL && map_usable(map, map_len, channels));
    *out_blank = ma_channel_map_is_blank((const ma_channel*)map, (ma_uint32)channels) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_channel_map_contains_channel_position */
int ma_shim_channel_map_contains_channel_position(
    unsigned int channels, const unsigned char* map, unsigned int map_len,
    unsigned int position, int* out_contains
) {
    if (out_contains != NULL) { *out_contains = 0; }
    MA_SHIM_REQUIRE(out_contains != NULL && position <= 255 && map_usable(map, map_len, channels));
    *out_contains = ma_channel_map_contains_channel_position(
        (ma_uint32)channels, (const ma_channel*)map, (ma_channel)position) ? 1 : 0;
    return MA_SUCCESS;
}

/* @binds ma_channel_map_find_channel_position */
int ma_shim_channel_map_find_channel_position(
    unsigned int channels, const unsigned char* map, unsigned int map_len,
    unsigned int position, int* out_found, unsigned int* out_index
) {
    ma_uint32 index = (ma_uint32)-1;

    if (out_found != NULL) { *out_found = 0; }
    if (out_index != NULL) { *out_index = (unsigned int)-1; }
    MA_SHIM_REQUIRE(out_found != NULL && out_index != NULL && position <= 255);
    MA_SHIM_REQUIRE(map_usable(map, map_len, channels));
    *out_found = ma_channel_map_find_channel_position(
        (ma_uint32)channels, (const ma_channel*)map, (ma_channel)position, &index) ? 1 : 0;
    *out_index = (unsigned int)index;
    return MA_SUCCESS;
}

/* @binds ma_channel_map_to_string */
int ma_shim_channel_map_to_string(
    const unsigned char* map, unsigned int map_len, unsigned int channels,
    char* out_text, unsigned int capacity, unsigned int* out_length
) {
    if (out_length != NULL) { *out_length = 0; }
    MA_SHIM_REQUIRE(out_length != NULL && map_usable(map, map_len, channels));
    if (out_text != NULL && capacity > 0) {
        memset(out_text, 0, capacity);
    }
    *out_length = (unsigned int)ma_channel_map_to_string(
        (const ma_channel*)map, (ma_uint32)channels, out_text, (size_t)capacity);
    return MA_SUCCESS;
}

/* @binds ma_channel_position_to_string */
int ma_shim_channel_position_to_string(unsigned int position, char* out_text, unsigned int capacity) {
    MA_SHIM_REQUIRE(out_text != NULL && capacity > 0 && position <= 255);
    strncpy(out_text, ma_channel_position_to_string((ma_channel)position), capacity - 1);
    out_text[capacity - 1] = '\0';
    return MA_SUCCESS;
}
