#include "ma_shim_vec3f.h"
#include "miniaudio.h"

#include <stdlib.h>

/* The ma_vec3f / ma_atomic_vec3f helpers are exported by miniaudio but have no
 * prototype in its public header (they are defined only inside the
 * implementation section), so declare them here. */
MA_API ma_vec3f ma_vec3f_init_3f(float x, float y, float z);
MA_API ma_vec3f ma_vec3f_sub(ma_vec3f a, ma_vec3f b);
MA_API ma_vec3f ma_vec3f_neg(ma_vec3f a);
MA_API float    ma_vec3f_dot(ma_vec3f a, ma_vec3f b);
MA_API float    ma_vec3f_len2(ma_vec3f v);
MA_API float    ma_vec3f_len(ma_vec3f v);
MA_API float    ma_vec3f_dist(ma_vec3f a, ma_vec3f b);
MA_API ma_vec3f ma_vec3f_normalize(ma_vec3f v);
MA_API ma_vec3f ma_vec3f_cross(ma_vec3f a, ma_vec3f b);
MA_API void     ma_atomic_vec3f_init(ma_atomic_vec3f* v, ma_vec3f value);
MA_API void     ma_atomic_vec3f_set(ma_atomic_vec3f* v, ma_vec3f value);
MA_API ma_vec3f ma_atomic_vec3f_get(ma_atomic_vec3f* v);

#define MA_SHIM_REQUIRE(cond) do { if (!(cond)) { return MA_INVALID_ARGS; } } while (0)

static ma_vec3f vec(float x, float y, float z) {
    return ma_vec3f_init_3f(x, y, z);
}

static int put(ma_vec3f v, float* out_x, float* out_y, float* out_z) {
    *out_x = v.x;
    *out_y = v.y;
    *out_z = v.z;
    return MA_SUCCESS;
}

/* @binds ma_vec3f_init_3f */
int ma_shim_vec3f_init_3f(float x, float y, float z, float* out_x, float* out_y, float* out_z) {
    MA_SHIM_REQUIRE(out_x != NULL && out_y != NULL && out_z != NULL);
    return put(ma_vec3f_init_3f(x, y, z), out_x, out_y, out_z);
}

/* @binds ma_vec3f_sub */
int ma_shim_vec3f_sub(
    float ax, float ay, float az, float bx, float by, float bz,
    float* out_x, float* out_y, float* out_z
) {
    MA_SHIM_REQUIRE(out_x != NULL && out_y != NULL && out_z != NULL);
    return put(ma_vec3f_sub(vec(ax, ay, az), vec(bx, by, bz)), out_x, out_y, out_z);
}

/* @binds ma_vec3f_neg */
int ma_shim_vec3f_neg(float x, float y, float z, float* out_x, float* out_y, float* out_z) {
    MA_SHIM_REQUIRE(out_x != NULL && out_y != NULL && out_z != NULL);
    return put(ma_vec3f_neg(vec(x, y, z)), out_x, out_y, out_z);
}

/* @binds ma_vec3f_dot */
int ma_shim_vec3f_dot(
    float ax, float ay, float az, float bx, float by, float bz, float* out_dot
) {
    MA_SHIM_REQUIRE(out_dot != NULL);
    *out_dot = ma_vec3f_dot(vec(ax, ay, az), vec(bx, by, bz));
    return MA_SUCCESS;
}

/* @binds ma_vec3f_cross */
int ma_shim_vec3f_cross(
    float ax, float ay, float az, float bx, float by, float bz,
    float* out_x, float* out_y, float* out_z
) {
    MA_SHIM_REQUIRE(out_x != NULL && out_y != NULL && out_z != NULL);
    return put(ma_vec3f_cross(vec(ax, ay, az), vec(bx, by, bz)), out_x, out_y, out_z);
}

/* @binds ma_vec3f_len2 */
int ma_shim_vec3f_len2(float x, float y, float z, float* out_len2) {
    MA_SHIM_REQUIRE(out_len2 != NULL);
    *out_len2 = ma_vec3f_len2(vec(x, y, z));
    return MA_SUCCESS;
}

/* @binds ma_vec3f_len */
int ma_shim_vec3f_len(float x, float y, float z, float* out_len) {
    MA_SHIM_REQUIRE(out_len != NULL);
    *out_len = ma_vec3f_len(vec(x, y, z));
    return MA_SUCCESS;
}

/* @binds ma_vec3f_dist */
int ma_shim_vec3f_dist(
    float ax, float ay, float az, float bx, float by, float bz, float* out_dist
) {
    MA_SHIM_REQUIRE(out_dist != NULL);
    *out_dist = ma_vec3f_dist(vec(ax, ay, az), vec(bx, by, bz));
    return MA_SUCCESS;
}

/* @binds ma_vec3f_normalize */
int ma_shim_vec3f_normalize(float x, float y, float z, float* out_x, float* out_y, float* out_z) {
    MA_SHIM_REQUIRE(out_x != NULL && out_y != NULL && out_z != NULL);
    return put(ma_vec3f_normalize(vec(x, y, z)), out_x, out_y, out_z);
}

/* ================= ma_atomic_vec3f ================= */

/* Bookkeeping around the vector so get / set before init fail deterministically. */
typedef struct ma_shim_atomic_vec3f {
    ma_atomic_vec3f value;
    int             initialized;
} ma_shim_atomic_vec3f;

static ma_shim_atomic_vec3f* atomic_ready(void* handle) {
    ma_shim_atomic_vec3f* h = (ma_shim_atomic_vec3f*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_atomic_vec3f_alloc(void) {
    return calloc(1, sizeof(ma_shim_atomic_vec3f));
}

void ma_shim_atomic_vec3f_free(void* handle) {
    free(handle);
}

/* @binds ma_atomic_vec3f_init */
int ma_shim_atomic_vec3f_init(void* handle, float x, float y, float z) {
    ma_shim_atomic_vec3f* h = (ma_shim_atomic_vec3f*)handle;
    MA_SHIM_REQUIRE(h != NULL);
    ma_atomic_vec3f_init(&h->value, vec(x, y, z));
    h->initialized = 1;
    return MA_SUCCESS;
}

/* @binds ma_atomic_vec3f_set */
int ma_shim_atomic_vec3f_set(void* handle, float x, float y, float z) {
    ma_shim_atomic_vec3f* h = atomic_ready(handle);
    MA_SHIM_REQUIRE(h != NULL);
    ma_atomic_vec3f_set(&h->value, vec(x, y, z));
    return MA_SUCCESS;
}

/* @binds ma_atomic_vec3f_get */
int ma_shim_atomic_vec3f_get(void* handle, float* out_x, float* out_y, float* out_z) {
    ma_shim_atomic_vec3f* h = atomic_ready(handle);
    if (out_x != NULL) { *out_x = 0; }
    if (out_y != NULL) { *out_y = 0; }
    if (out_z != NULL) { *out_z = 0; }
    MA_SHIM_REQUIRE(h != NULL && out_x != NULL && out_y != NULL && out_z != NULL);
    return put(ma_atomic_vec3f_get(&h->value), out_x, out_y, out_z);
}
