#ifndef MA_SHIM_INTERNAL_H
#define MA_SHIM_INTERNAL_H

/*
 * Cross-family internal helpers shared between ma_shim_<family>.c translation
 * units. These deliberately do NOT use the `ma_shim_` prefix so the coverage
 * checker (which treats every `ma_shim_*` export as a public binding needing an
 * L2 wrapper + test) ignores them.
 */

#include "miniaudio.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Resolve an engine handle (from ma_shim_engine_alloc + ma_shim_engine_init) to
 * its underlying ma_engine*, or NULL if the handle is null/uninitialised.
 * Defined in ma_shim_engine.c. */
ma_engine* shimint_engine_ptr(void* engine_handle);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_INTERNAL_H */
