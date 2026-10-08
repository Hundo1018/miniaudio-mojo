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

/* The reverse: the shim engine handle whose embedded ma_engine is `engine`, or
 * NULL for NULL. Only meaningful for an ma_engine that lives inside a shim
 * engine handle, which is the only kind this shim ever creates. Defined in
 * ma_shim_engine.c. */
void* shimint_engine_handle(ma_engine* engine);

/* Resolve a data-source handle the shim owns to its ma_data_source*, or NULL if
 * it is null, not ready, or a borrowed view of a sound's data source. Use it
 * anywhere the pointer is *kept* (a sound's data source, a chain link, a node's
 * source): a view does not own what it points at, so nothing may outlive it by
 * holding that pointer. Defined in ma_shim_data_source.c. */
ma_data_source* shimint_data_source_ptr_owned(void* handle);

/* Resolve a sound handle to its ma_sound*, or NULL if null/uninitialised.
 * Defined in ma_shim_sound.c. */
ma_sound* shimint_sound_ptr(void* sound_handle);

/* A sound handle is reference counted so a borrowed view of its data source can
 * outlive the Mojo Sound without dangling. The sound itself is still torn down
 * when its owner frees or uninits it; only the small bookkeeping wrapper
 * persists, as an empty shell that every call rejects. A handle starts with one
 * reference (the owner's); ma_shim_sound_free drops it. */
void shimint_sound_retain(void* sound_handle);
void shimint_sound_release(void* sound_handle);

/* A sound group handle as the ma_node* it presents (a group is a ma_sound whose
 * first member is its engine node), or NULL if null/uninitialised. Defined in
 * ma_shim_sound_group.c. */
ma_node* shimint_sound_group_node(void* group_handle);

/* Any shim node handle (offset, delay, splitter, engine node, borrowed
 * endpoint) as its ma_node*, or NULL if null/not ready. Defined in
 * ma_shim_node.c. */
ma_node* shimint_node_ptr(void* node_handle);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_INTERNAL_H */
