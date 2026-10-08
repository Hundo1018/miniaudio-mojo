#ifndef MA_SHIM_NODE_H
#define MA_SHIM_NODE_H

/* ---- node graph (opaque handles over ma_node_graph and the node family) ----
 *
 * A node graph is a tree of processing nodes feeding an endpoint. Reading from
 * the graph pulls audio through it. Nothing here needs a device or an engine:
 * the graph is created standalone, so the whole family is deterministic.
 *
 * miniaudio's `ma_node_init` takes a vtable — the caller supplies the node's
 * processing callback. A Mojo function cannot cross the FFI boundary as a
 * function pointer on this toolchain (the same constraint the device family
 * documents), so the shim owns a concrete node instead: an **offset node**,
 * which adds a constant to whatever arrives on its input bus. With nothing
 * attached it emits that constant; with another node attached it adds to it.
 * That makes every accessor in the node family reachable — input and output
 * buses, channels, volume, state, timing — and makes chains observable, since
 * two offset nodes in series produce twice the offset.
 *
 * `ma_node_get_node_graph` and `ma_node_graph_get_endpoint` hand out raw
 * pointers with no safe Mojo home. They are bound the way the data_source
 * family binds its cursor pointers: as the questions Mojo can actually ask —
 * "does this node belong to that graph?" and "attach my output to the graph's
 * endpoint".
 *
 * Node state codes match ma_node_state: started=0, stopped=1.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ================= ma_node_graph ================= */

void* ma_shim_node_graph_alloc(void);
void  ma_shim_node_graph_free(void* handle);

int ma_shim_node_graph_init(void* handle, unsigned int channels);
int ma_shim_node_graph_uninit(void* handle);

/* Pulls frame_count frames through the graph into `dst`. */
int ma_shim_node_graph_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
);

int ma_shim_node_graph_get_channels(void* handle, unsigned int* out_channels);
int ma_shim_node_graph_get_time(void* handle, unsigned long long* out_time);
int ma_shim_node_graph_set_time(void* handle, unsigned long long global_time);
int ma_shim_node_graph_get_processing_size(void* handle, unsigned int* out_frames);

/* The endpoint is a node; this reports its input bus count, which is the only
 * part of it Mojo can hold on to. */
int ma_shim_node_graph_endpoint_input_bus_count(void* handle, unsigned int* out_count);

/* ================= the shim's offset node ================= */

void* ma_shim_node_alloc(void);
void  ma_shim_node_free(void* handle);

/* `offset` is the constant this node adds to its input. */
int ma_shim_node_init(
    void*        handle,
    void*        graph_handle,
    unsigned int channels,
    float        offset
);
int ma_shim_node_init_preallocated(
    void*        handle,
    void*        graph_handle,
    unsigned int channels,
    float        offset
);
int ma_shim_node_get_heap_size(
    void* graph_handle, unsigned int channels, unsigned long long* out_heap_size);
int ma_shim_node_uninit(void* handle);

int ma_shim_node_attach_output_bus(
    void* handle, unsigned int output_bus, void* other_handle, unsigned int other_input_bus);
/* Attach this node's output bus straight to the graph's endpoint. */
int ma_shim_node_attach_to_endpoint(
    void* handle, unsigned int output_bus, void* graph_handle, unsigned int endpoint_input_bus);
int ma_shim_node_detach_output_bus(void* handle, unsigned int output_bus);
int ma_shim_node_detach_all_output_buses(void* handle);

int ma_shim_node_set_output_bus_volume(void* handle, unsigned int output_bus, float volume);
int ma_shim_node_get_output_bus_volume(void* handle, unsigned int output_bus, float* out_volume);

int ma_shim_node_get_input_bus_count(void* handle, unsigned int* out_count);
int ma_shim_node_get_output_bus_count(void* handle, unsigned int* out_count);
int ma_shim_node_get_input_channels(void* handle, unsigned int bus, unsigned int* out_channels);
int ma_shim_node_get_output_channels(void* handle, unsigned int bus, unsigned int* out_channels);

int ma_shim_node_set_state(void* handle, int state);
int ma_shim_node_get_state(void* handle, int* out_state);
int ma_shim_node_set_state_time(void* handle, int state, unsigned long long global_time);
int ma_shim_node_get_state_time(void* handle, int state, unsigned long long* out_time);
int ma_shim_node_get_state_by_time(void* handle, unsigned long long global_time, int* out_state);
int ma_shim_node_get_state_by_time_range(
    void* handle, unsigned long long begin, unsigned long long end, int* out_state);
int ma_shim_node_get_time(void* handle, unsigned long long* out_time);
int ma_shim_node_set_time(void* handle, unsigned long long local_time);

/* "Does this node belong to that graph?" — get_node_graph as an identity test. */
int ma_shim_node_belongs_to_graph(void* handle, void* graph_handle, int* out_same);

/* ================= borrowed views of an engine's graph ================= */

/* Make a graph handle (ma_shim_node_graph_alloc) a non-owning view of the
 * engine's own node graph. The view is used like any graph handle; freeing or
 * uninitialising it leaves the engine's graph alone. The engine must outlive it. */
int ma_shim_node_graph_borrow_engine(void* graph_handle, void* engine_handle);

/* Make a node handle (ma_shim_node_alloc) a non-owning view of the engine's
 * endpoint node. It can be attached to, queried, and have its bus volume set
 * through the generic ma_shim_node_* operations. */
int ma_shim_node_borrow_engine_endpoint(void* node_handle, void* engine_handle);

/* "Is this node that graph's endpoint?" — ma_node_graph_get_endpoint as an identity test. */
int ma_shim_node_is_graph_endpoint(void* node_handle, void* graph_handle, int* out_same);

/* ================= ma_engine_node ================= */

/* A group-flavoured engine node: one input bus fed by upstream nodes, run
 * through the engine's pitch / fade / spatialise / pan stage, one output bus.
 * `flags` are MA_SOUND_FLAG_* (NO_PITCH, NO_SPATIALIZATION apply); channels of 0
 * mean "the engine's"; the generic ma_shim_node_* operations work on the handle. */
void* ma_shim_engine_node_alloc(void);
void  ma_shim_engine_node_free(void* handle);

int ma_shim_engine_node_get_heap_size(
    void* engine_handle, unsigned int flags,
    unsigned int channels_in, unsigned int channels_out, unsigned int volume_smooth_time,
    unsigned long long* out_heap_size);
int ma_shim_engine_node_init(
    void* handle, void* engine_handle, unsigned int flags,
    unsigned int channels_in, unsigned int channels_out, unsigned int volume_smooth_time,
    unsigned int pinned_listener_index);
/* Same, through miniaudio's preallocated-heap path with a shim-owned block. */
int ma_shim_engine_node_init_preallocated(
    void* handle, void* engine_handle, unsigned int flags,
    unsigned int channels_in, unsigned int channels_out, unsigned int volume_smooth_time,
    unsigned int pinned_listener_index);
int ma_shim_engine_node_uninit(void* handle);

/* ================= ma_delay_node ================= */

void* ma_shim_delay_node_alloc(void);
void  ma_shim_delay_node_free(void* handle);

int ma_shim_delay_node_init(
    void*        handle,
    void*        graph_handle,
    unsigned int channels,
    unsigned int sample_rate,
    unsigned int delay_in_frames,
    float        decay
);
int ma_shim_delay_node_uninit(void* handle);
int ma_shim_delay_node_attach_to_endpoint(void* handle, void* graph_handle);

int ma_shim_delay_node_set_wet(void* handle, float value);
int ma_shim_delay_node_get_wet(void* handle, float* out_value);
int ma_shim_delay_node_set_dry(void* handle, float value);
int ma_shim_delay_node_get_dry(void* handle, float* out_value);
int ma_shim_delay_node_set_decay(void* handle, float value);
int ma_shim_delay_node_get_decay(void* handle, float* out_value);

/* ================= ma_splitter_node ================= */

void* ma_shim_splitter_node_alloc(void);
void  ma_shim_splitter_node_free(void* handle);

int ma_shim_splitter_node_init(void* handle, void* graph_handle, unsigned int channels);
int ma_shim_splitter_node_uninit(void* handle);
int ma_shim_splitter_node_attach_to_endpoint(
    void* handle, unsigned int output_bus, void* graph_handle);

#ifdef __cplusplus
}
#endif

#endif /* MA_SHIM_NODE_H */
