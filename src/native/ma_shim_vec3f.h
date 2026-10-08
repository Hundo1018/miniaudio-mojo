#ifndef MA_SHIM_VEC3F_H
#define MA_SHIM_VEC3F_H

/* ---- 3D vector math ----
 *
 * miniaudio's ma_vec3f helpers: construction, subtraction, negation, dot and
 * cross products, length, distance and normalisation, plus ma_atomic_vec3f (a
 * vector guarded by a spinlock so one thread can set it while another reads).
 *
 * ma_vec3f crosses the ABI by value in miniaudio, which a C-FFI call cannot do
 * portably, so here every vector is three floats (x, y, z) in and three out
 * pointers out. The ma_atomic_vec3f is an opaque handle: alloc / free, with
 * init (re)initialising it to a value, set and get.
 *
 * Every entry point returns a ma_result code; MA_INVALID_ARGS for a missing out
 * pointer or a null / never-initialised atomic handle.
 */

#ifdef __cplusplus
extern "C" {
#endif

int ma_shim_vec3f_init_3f(float x, float y, float z, float* out_x, float* out_y, float* out_z);
int ma_shim_vec3f_sub(
    float ax, float ay, float az, float bx, float by, float bz,
    float* out_x, float* out_y, float* out_z);
int ma_shim_vec3f_neg(float x, float y, float z, float* out_x, float* out_y, float* out_z);
int ma_shim_vec3f_dot(
    float ax, float ay, float az, float bx, float by, float bz, float* out_dot);
int ma_shim_vec3f_cross(
    float ax, float ay, float az, float bx, float by, float bz,
    float* out_x, float* out_y, float* out_z);
int ma_shim_vec3f_len2(float x, float y, float z, float* out_len2);
int ma_shim_vec3f_len(float x, float y, float z, float* out_len);
int ma_shim_vec3f_dist(
    float ax, float ay, float az, float bx, float by, float bz, float* out_dist);
/* The zero vector normalises to the zero vector. */
int ma_shim_vec3f_normalize(float x, float y, float z, float* out_x, float* out_y, float* out_z);

/* ---- ma_atomic_vec3f ---- */
void* ma_shim_atomic_vec3f_alloc(void);
void  ma_shim_atomic_vec3f_free(void* handle);
int   ma_shim_atomic_vec3f_init(void* handle, float x, float y, float z);
int   ma_shim_atomic_vec3f_set(void* handle, float x, float y, float z);
int   ma_shim_atomic_vec3f_get(void* handle, float* out_x, float* out_y, float* out_z);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_VEC3F_H */
