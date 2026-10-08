#ifndef MA_SHIM_CHANNEL_MAP_H
#define MA_SHIM_CHANNEL_MAP_H

/* ---- channel maps ----
 *
 * A channel map is a plain array of one byte per channel (ma_channel), naming
 * the speaker position of that channel. There are no handles here: every entry
 * point is a call on caller memory.
 *
 * Buffer contract. Every buffer comes with its length in entries (`map_len`,
 * `out_cap`), so the shim can refuse a buffer that is too short instead of
 * letting miniaudio read or write past it. A NULL input map with length 0 means
 * "the default map for that channel count", which is what miniaudio's lookup
 * functions do for NULL; only the output of an init / copy needs real memory.
 *
 * Codes: a standard map is ma_standard_channel_map (microsoft = 0 = default,
 * alsa, rfc3551, flac, vorbis, sound4, sndio = 6); a channel position is
 * ma_channel (none = 0, mono = 1, front_left = 2 ... aux_31 = 51), any value
 * 0..255.
 *
 * Every entry point returns a ma_result code; answers come back through out
 * pointers, with booleans as int 0 / 1.
 */

#ifdef __cplusplus
extern "C" {
#endif

int ma_shim_channel_map_init_blank(unsigned char* map, unsigned int map_cap, unsigned int channels);

/* Fills at most `map_cap` entries even when channels is larger (miniaudio's cap). */
int ma_shim_channel_map_init_standard(
    int standard, unsigned char* map, unsigned int map_cap, unsigned int channels);

int ma_shim_channel_map_copy(
    unsigned char* out, unsigned int out_cap,
    const unsigned char* in, unsigned int in_len, unsigned int channels);

/* NULL `in` fills the default map (respecting out_cap); otherwise copies. */
int ma_shim_channel_map_copy_or_default(
    unsigned char* out, unsigned int out_cap,
    const unsigned char* in, unsigned int in_len, unsigned int channels);

int ma_shim_channel_map_get_channel(
    const unsigned char* map, unsigned int map_len,
    unsigned int channel_count, unsigned int channel_index, unsigned int* out_channel);

int ma_shim_channel_map_is_valid(
    const unsigned char* map, unsigned int map_len, unsigned int channels, int* out_valid);

int ma_shim_channel_map_is_equal(
    const unsigned char* a, unsigned int a_len,
    const unsigned char* b, unsigned int b_len, unsigned int channels, int* out_equal);

/* A NULL map is the default map, which is never blank. */
int ma_shim_channel_map_is_blank(
    const unsigned char* map, unsigned int map_len, unsigned int channels, int* out_blank);

int ma_shim_channel_map_contains_channel_position(
    unsigned int channels, const unsigned char* map, unsigned int map_len,
    unsigned int position, int* out_contains);

/* out_index is 0xFFFFFFFF when the position is absent. */
int ma_shim_channel_map_find_channel_position(
    unsigned int channels, const unsigned char* map, unsigned int map_len,
    unsigned int position, int* out_found, unsigned int* out_index);

/* Space-separated names. `out_length` is the full length miniaudio computes,
 * even when `capacity` truncated the text; out_text may be NULL to ask for just
 * the length. The buffer is zero-filled first so a truncated result is a clean
 * prefix of whole names. */
int ma_shim_channel_map_to_string(
    const unsigned char* map, unsigned int map_len, unsigned int channels,
    char* out_text, unsigned int capacity, unsigned int* out_length);

int ma_shim_channel_position_to_string(unsigned int position, char* out_text, unsigned int capacity);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_CHANNEL_MAP_H */
