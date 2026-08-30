#include "ma_shim_node.h"
#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>

/* ================= ma_node_graph ================= */

typedef struct ma_shim_node_graph_state {
    ma_node_graph graph;
    int           initialized;
} ma_shim_node_graph_state;

static void node_graph_teardown(ma_shim_node_graph_state* h) {
    if (h->initialized) {
        ma_node_graph_uninit(&h->graph, NULL);
        h->initialized = 0;
    }
}

static ma_shim_node_graph_state* node_graph_ready(void* handle) {
    ma_shim_node_graph_state* h = (ma_shim_node_graph_state*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return h;
}

void* ma_shim_node_graph_alloc(void) {
    return calloc(1, sizeof(ma_shim_node_graph_state));
}

/* @binds ma_node_graph_uninit */
void ma_shim_node_graph_free(void* handle) {
    ma_shim_node_graph_state* h = (ma_shim_node_graph_state*)handle;
    if (h == NULL) {
        return;
    }
    node_graph_teardown(h);
    free(h);
}

/* @binds ma_node_graph_config_init, ma_node_graph_init */
int ma_shim_node_graph_init(void* handle, unsigned int channels) {
    ma_shim_node_graph_state* h = (ma_shim_node_graph_state*)handle;
    ma_node_graph_config      config;
    ma_result                 result;

    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    node_graph_teardown(h);

    config = ma_node_graph_config_init((ma_uint32)channels);
    result = ma_node_graph_init(&config, NULL, &h->graph);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_node_graph_uninit */
int ma_shim_node_graph_uninit(void* handle) {
    ma_shim_node_graph_state* h = (ma_shim_node_graph_state*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    node_graph_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_node_graph_read_pcm_frames */
int ma_shim_node_graph_read(
    void*               handle,
    void*               dst,
    unsigned long long  frame_count,
    unsigned long long* frames_read_out
) {
    ma_shim_node_graph_state* h = node_graph_ready(handle);
    ma_uint64                 read = 0;
    ma_result                 result;

    if (frames_read_out != NULL) { *frames_read_out = 0; }
    if (h == NULL || dst == NULL) {
        return MA_INVALID_ARGS;
    }
    result = ma_node_graph_read_pcm_frames(&h->graph, dst, (ma_uint64)frame_count, &read);
    if (frames_read_out != NULL) { *frames_read_out = (unsigned long long)read; }
    return (int)result;
}

/* @binds ma_node_graph_get_channels */
int ma_shim_node_graph_get_channels(void* handle, unsigned int* out_channels) {
    ma_shim_node_graph_state* h = node_graph_ready(handle);
    if (out_channels != NULL) { *out_channels = 0; }
    if (h == NULL || out_channels == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_channels = (unsigned int)ma_node_graph_get_channels(&h->graph);
    return MA_SUCCESS;
}

/* @binds ma_node_graph_get_time */
int ma_shim_node_graph_get_time(void* handle, unsigned long long* out_time) {
    ma_shim_node_graph_state* h = node_graph_ready(handle);
    if (out_time != NULL) { *out_time = 0; }
    if (h == NULL || out_time == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_time = (unsigned long long)ma_node_graph_get_time(&h->graph);
    return MA_SUCCESS;
}

/* @binds ma_node_graph_set_time */
int ma_shim_node_graph_set_time(void* handle, unsigned long long global_time) {
    ma_shim_node_graph_state* h = node_graph_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_graph_set_time(&h->graph, (ma_uint64)global_time);
}

/* @binds ma_node_graph_get_processing_size_in_frames */
int ma_shim_node_graph_get_processing_size(void* handle, unsigned int* out_frames) {
    ma_shim_node_graph_state* h = node_graph_ready(handle);
    if (out_frames != NULL) { *out_frames = 0; }
    if (h == NULL || out_frames == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_frames = (unsigned int)ma_node_graph_get_processing_size_in_frames(&h->graph);
    return MA_SUCCESS;
}

/* @binds ma_node_graph_get_endpoint, ma_node_get_input_bus_count */
int ma_shim_node_graph_endpoint_input_bus_count(void* handle, unsigned int* out_count) {
    ma_shim_node_graph_state* h = node_graph_ready(handle);
    ma_node*                  endpoint;

    if (out_count != NULL) { *out_count = 0; }
    if (h == NULL || out_count == NULL) {
        return MA_INVALID_ARGS;
    }
    endpoint = ma_node_graph_get_endpoint(&h->graph);
    if (endpoint == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_count = (unsigned int)ma_node_get_input_bus_count(endpoint);
    return MA_SUCCESS;
}

/* ================= the shim's offset node ================= */

/* Adds a constant to whatever arrives on its input bus. With nothing attached
 * the input is silence, so the node emits the constant on its own. */
typedef struct ma_shim_offset_node {
    ma_node_base base;
    float        offset;
    ma_uint32    channels;
} ma_shim_offset_node;

static void offset_node_process(
    ma_node*      pNode,
    const float** ppFramesIn,
    ma_uint32*    pFrameCountIn,
    float**       ppFramesOut,
    ma_uint32*    pFrameCountOut
) {
    ma_shim_offset_node* node = (ma_shim_offset_node*)pNode;
    ma_uint32            frames = *pFrameCountOut;
    ma_uint32            available = (ppFramesIn != NULL) ? *pFrameCountIn : 0;
    ma_uint32            channels = node->channels;
    ma_uint32            i;
    ma_uint32            c;

    for (i = 0; i < frames; i += 1) {
        for (c = 0; c < channels; c += 1) {
            float in = 0;
            if (ppFramesIn != NULL && ppFramesIn[0] != NULL && i < available) {
                in = ppFramesIn[0][i * channels + c];
            }
            ppFramesOut[0][i * channels + c] = in + node->offset;
        }
    }

    /* Everything offered was consumed, and a full buffer was produced. */
    *pFrameCountIn = available;
    *pFrameCountOut = frames;
}

static ma_node_vtable g_offset_node_vtable = {
    offset_node_process,
    NULL,   /* onGetRequiredInputFrameCount */
    1,      /* inputBusCount  */
    1,      /* outputBusCount */
    /* CONTINUOUS_PROCESSING keeps the callback running when nothing is attached
     * to the input bus, which is what lets the node act as a source;
     * ALLOW_NULL_INPUT is its companion, and says the input pointer may be NULL
     * in that case. Without these a node with an unattached input bus is simply
     * skipped and contributes nothing. */
    MA_NODE_FLAG_CONTINUOUS_PROCESSING | MA_NODE_FLAG_ALLOW_NULL_INPUT
};

/* Every node handle in this shim is the same allocation: a kind tag plus a
 * union of the payloads. Each payload starts with a ma_node_base, so `ma_node*`
 * for any of them is the address of the union — which is what lets one node be
 * attached to another regardless of which family either came from. Casting one
 * family's handle to another's struct would be undefined behaviour; this is the
 * defined way to get the same reach. */
typedef enum ma_shim_node_kind {
    MA_SHIM_NODE_KIND_OFFSET = 0,
    MA_SHIM_NODE_KIND_DELAY,
    MA_SHIM_NODE_KIND_SPLITTER
} ma_shim_node_kind;

typedef struct ma_shim_any_node {
    ma_shim_node_kind kind;
    int               initialized;
    void*             heap;   /* non-NULL when the preallocated path was used */
    union {
        ma_shim_offset_node offset;
        ma_delay_node       delay;
        ma_splitter_node    splitter;
    } payload;
} ma_shim_any_node;

typedef ma_shim_any_node ma_shim_node_state;

/* The ma_node every kind of payload starts with, or NULL if not ready. */
static ma_node* any_node_ptr(void* handle) {
    ma_shim_any_node* h = (ma_shim_any_node*)handle;
    if (h == NULL || !h->initialized) {
        return NULL;
    }
    return (ma_node*)&h->payload;
}

static void node_teardown(ma_shim_node_state* h) {
    if (h->initialized) {
        ma_node_uninit((ma_node*)&h->payload.offset, NULL);
        h->initialized = 0;
    }
    free(h->heap);
    h->heap = NULL;
}

static ma_shim_node_state* node_ready(void* handle) {
    ma_shim_node_state* h = (ma_shim_node_state*)handle;
    if (h == NULL || !h->initialized || h->kind != MA_SHIM_NODE_KIND_OFFSET) {
        return NULL;
    }
    return h;
}

/* The offset node's config: one input bus and one output bus, both `channels`. */
static ma_node_config offset_node_config(const ma_uint32* channels) {
    ma_node_config config = ma_node_config_init();
    config.vtable = &g_offset_node_vtable;
    config.pInputChannels = channels;
    config.pOutputChannels = channels;
    return config;
}

void* ma_shim_node_alloc(void) {
    ma_shim_any_node* h = (ma_shim_any_node*)calloc(1, sizeof(ma_shim_any_node));
    if (h != NULL) { h->kind = MA_SHIM_NODE_KIND_OFFSET; }
    return h;
}

/* @binds ma_node_uninit */
void ma_shim_node_free(void* handle) {
    ma_shim_node_state* h = (ma_shim_node_state*)handle;
    if (h == NULL) {
        return;
    }
    node_teardown(h);
    free(h);
}

/* @binds ma_node_config_init, ma_node_get_heap_size */
int ma_shim_node_get_heap_size(
    void* graph_handle, unsigned int channels, unsigned long long* out_heap_size
) {
    ma_shim_node_graph_state* g = node_graph_ready(graph_handle);
    ma_uint32                 ch = (ma_uint32)channels;
    ma_node_config            config;
    size_t                    size = 0;
    ma_result                 result;

    if (out_heap_size != NULL) { *out_heap_size = 0; }
    if (g == NULL || out_heap_size == NULL) {
        return MA_INVALID_ARGS;
    }
    config = offset_node_config(&ch);
    result = ma_node_get_heap_size(&g->graph, &config, &size);
    *out_heap_size = (unsigned long long)size;
    return (int)result;
}

/* @binds ma_node_config_init, ma_node_init */
int ma_shim_node_init(
    void* handle, void* graph_handle, unsigned int channels, float offset
) {
    ma_shim_node_state*       h = (ma_shim_node_state*)handle;
    ma_shim_node_graph_state* g = node_graph_ready(graph_handle);
    ma_uint32                 ch = (ma_uint32)channels;
    ma_node_config            config;
    ma_result                 result;

    if (h == NULL || g == NULL) {
        return MA_INVALID_ARGS;
    }
    node_teardown(h);

    h->payload.offset.offset = offset;
    h->payload.offset.channels = ch;

    config = offset_node_config(&ch);
    result = ma_node_init(&g->graph, &config, NULL, (ma_node*)&h->payload.offset);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_node_config_init, ma_node_get_heap_size, ma_node_init_preallocated */
int ma_shim_node_init_preallocated(
    void* handle, void* graph_handle, unsigned int channels, float offset
) {
    ma_shim_node_state*       h = (ma_shim_node_state*)handle;
    ma_shim_node_graph_state* g = node_graph_ready(graph_handle);
    ma_uint32                 ch = (ma_uint32)channels;
    ma_node_config            config;
    size_t                    heap_size = 0;
    void*                     heap = NULL;
    ma_result                 result;

    if (h == NULL || g == NULL) {
        return MA_INVALID_ARGS;
    }
    node_teardown(h);

    h->payload.offset.offset = offset;
    h->payload.offset.channels = ch;

    config = offset_node_config(&ch);
    result = ma_node_get_heap_size(&g->graph, &config, &heap_size);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    if (heap_size > 0) {
        heap = calloc(1, heap_size);
        if (heap == NULL) {
            return MA_OUT_OF_MEMORY;
        }
    }

    result = ma_node_init_preallocated(&g->graph, &config, heap, (ma_node*)&h->payload.offset);
    if (result == MA_SUCCESS) {
        h->heap = heap;
        h->initialized = 1;
    } else {
        free(heap);
    }
    return (int)result;
}

/* @binds ma_node_uninit */
int ma_shim_node_uninit(void* handle) {
    ma_shim_node_state* h = (ma_shim_node_state*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    node_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_node_attach_output_bus */
int ma_shim_node_attach_output_bus(
    void* handle, unsigned int output_bus, void* other_handle, unsigned int other_input_bus
) {
    ma_shim_node_state* h = node_ready(handle);
    ma_node*            other = any_node_ptr(other_handle);

    if (h == NULL || other == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_attach_output_bus(
        (ma_node*)&h->payload.offset, (ma_uint32)output_bus, other, (ma_uint32)other_input_bus);
}

/* @binds ma_node_graph_get_endpoint, ma_node_attach_output_bus */
int ma_shim_node_attach_to_endpoint(
    void* handle, unsigned int output_bus, void* graph_handle, unsigned int endpoint_input_bus
) {
    ma_shim_node_state*       h = node_ready(handle);
    ma_shim_node_graph_state* g = node_graph_ready(graph_handle);
    ma_node*                  endpoint;

    if (h == NULL || g == NULL) {
        return MA_INVALID_ARGS;
    }
    endpoint = ma_node_graph_get_endpoint(&g->graph);
    if (endpoint == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_attach_output_bus(
        (ma_node*)&h->payload.offset, (ma_uint32)output_bus, endpoint, (ma_uint32)endpoint_input_bus);
}

/* @binds ma_node_detach_output_bus */
int ma_shim_node_detach_output_bus(void* handle, unsigned int output_bus) {
    ma_shim_node_state* h = node_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_detach_output_bus((ma_node*)&h->payload.offset, (ma_uint32)output_bus);
}

/* @binds ma_node_detach_all_output_buses */
int ma_shim_node_detach_all_output_buses(void* handle) {
    ma_shim_node_state* h = node_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_detach_all_output_buses((ma_node*)&h->payload.offset);
}

/* @binds ma_node_set_output_bus_volume */
int ma_shim_node_set_output_bus_volume(void* handle, unsigned int output_bus, float volume) {
    ma_shim_node_state* h = node_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_set_output_bus_volume((ma_node*)&h->payload.offset, (ma_uint32)output_bus, volume);
}

/* @binds ma_node_get_output_bus_volume */
int ma_shim_node_get_output_bus_volume(void* handle, unsigned int output_bus, float* out_volume) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_volume != NULL) { *out_volume = 0; }
    if (h == NULL || out_volume == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_volume = ma_node_get_output_bus_volume((ma_node*)&h->payload.offset, (ma_uint32)output_bus);
    return MA_SUCCESS;
}

/* @binds ma_node_get_input_bus_count */
int ma_shim_node_get_input_bus_count(void* handle, unsigned int* out_count) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_count != NULL) { *out_count = 0; }
    if (h == NULL || out_count == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_count = (unsigned int)ma_node_get_input_bus_count((ma_node*)&h->payload.offset);
    return MA_SUCCESS;
}

/* @binds ma_node_get_output_bus_count */
int ma_shim_node_get_output_bus_count(void* handle, unsigned int* out_count) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_count != NULL) { *out_count = 0; }
    if (h == NULL || out_count == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_count = (unsigned int)ma_node_get_output_bus_count((ma_node*)&h->payload.offset);
    return MA_SUCCESS;
}

/* @binds ma_node_get_input_channels */
int ma_shim_node_get_input_channels(void* handle, unsigned int bus, unsigned int* out_channels) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_channels != NULL) { *out_channels = 0; }
    if (h == NULL || out_channels == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_channels = (unsigned int)ma_node_get_input_channels((ma_node*)&h->payload.offset, (ma_uint32)bus);
    return MA_SUCCESS;
}

/* @binds ma_node_get_output_channels */
int ma_shim_node_get_output_channels(void* handle, unsigned int bus, unsigned int* out_channels) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_channels != NULL) { *out_channels = 0; }
    if (h == NULL || out_channels == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_channels = (unsigned int)ma_node_get_output_channels((ma_node*)&h->payload.offset, (ma_uint32)bus);
    return MA_SUCCESS;
}

/* @binds ma_node_set_state */
int ma_shim_node_set_state(void* handle, int state) {
    ma_shim_node_state* h = node_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_set_state((ma_node*)&h->payload.offset, (ma_node_state)state);
}

/* @binds ma_node_get_state */
int ma_shim_node_get_state(void* handle, int* out_state) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_state != NULL) { *out_state = 0; }
    if (h == NULL || out_state == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_state = (int)ma_node_get_state((ma_node*)&h->payload.offset);
    return MA_SUCCESS;
}

/* @binds ma_node_set_state_time */
int ma_shim_node_set_state_time(void* handle, int state, unsigned long long global_time) {
    ma_shim_node_state* h = node_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_set_state_time(
        (ma_node*)&h->payload.offset, (ma_node_state)state, (ma_uint64)global_time);
}

/* @binds ma_node_get_state_time */
int ma_shim_node_get_state_time(void* handle, int state, unsigned long long* out_time) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_time != NULL) { *out_time = 0; }
    if (h == NULL || out_time == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_time = (unsigned long long)ma_node_get_state_time(
        (ma_node*)&h->payload.offset, (ma_node_state)state);
    return MA_SUCCESS;
}

/* @binds ma_node_get_state_by_time */
int ma_shim_node_get_state_by_time(
    void* handle, unsigned long long global_time, int* out_state
) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_state != NULL) { *out_state = 0; }
    if (h == NULL || out_state == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_state = (int)ma_node_get_state_by_time((ma_node*)&h->payload.offset, (ma_uint64)global_time);
    return MA_SUCCESS;
}

/* @binds ma_node_get_state_by_time_range */
int ma_shim_node_get_state_by_time_range(
    void* handle, unsigned long long begin, unsigned long long end, int* out_state
) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_state != NULL) { *out_state = 0; }
    if (h == NULL || out_state == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_state = (int)ma_node_get_state_by_time_range(
        (ma_node*)&h->payload.offset, (ma_uint64)begin, (ma_uint64)end);
    return MA_SUCCESS;
}

/* @binds ma_node_get_time */
int ma_shim_node_get_time(void* handle, unsigned long long* out_time) {
    ma_shim_node_state* h = node_ready(handle);
    if (out_time != NULL) { *out_time = 0; }
    if (h == NULL || out_time == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_time = (unsigned long long)ma_node_get_time((ma_node*)&h->payload.offset);
    return MA_SUCCESS;
}

/* @binds ma_node_set_time */
int ma_shim_node_set_time(void* handle, unsigned long long local_time) {
    ma_shim_node_state* h = node_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_set_time((ma_node*)&h->payload.offset, (ma_uint64)local_time);
}

/* @binds ma_node_get_node_graph */
int ma_shim_node_belongs_to_graph(void* handle, void* graph_handle, int* out_same) {
    ma_shim_node_state*       h = node_ready(handle);
    ma_shim_node_graph_state* g = node_graph_ready(graph_handle);

    if (out_same != NULL) { *out_same = 0; }
    if (h == NULL || g == NULL || out_same == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_same = ma_node_get_node_graph((ma_node*)&h->payload.offset) == &g->graph ? 1 : 0;
    return MA_SUCCESS;
}

/* ================= ma_delay_node ================= */

typedef ma_shim_any_node ma_shim_delay_node_state;

static void delay_node_teardown(ma_shim_delay_node_state* h) {
    if (h->initialized) {
        ma_delay_node_uninit(&h->payload.delay, NULL);
        h->initialized = 0;
    }
}

static ma_shim_delay_node_state* delay_node_ready(void* handle) {
    ma_shim_delay_node_state* h = (ma_shim_delay_node_state*)handle;
    if (h == NULL || !h->initialized || h->kind != MA_SHIM_NODE_KIND_DELAY) {
        return NULL;
    }
    return h;
}

void* ma_shim_delay_node_alloc(void) {
    ma_shim_any_node* h = (ma_shim_any_node*)calloc(1, sizeof(ma_shim_any_node));
    if (h != NULL) { h->kind = MA_SHIM_NODE_KIND_DELAY; }
    return h;
}

/* @binds ma_delay_node_uninit */
void ma_shim_delay_node_free(void* handle) {
    ma_shim_delay_node_state* h = (ma_shim_delay_node_state*)handle;
    if (h == NULL) {
        return;
    }
    delay_node_teardown(h);
    free(h);
}

/* @binds ma_delay_node_config_init, ma_delay_node_init */
int ma_shim_delay_node_init(
    void*        handle,
    void*        graph_handle,
    unsigned int channels,
    unsigned int sample_rate,
    unsigned int delay_in_frames,
    float        decay
) {
    ma_shim_delay_node_state* h = (ma_shim_delay_node_state*)handle;
    ma_shim_node_graph_state* g = node_graph_ready(graph_handle);
    ma_delay_node_config      config;
    ma_result                 result;

    if (h == NULL || g == NULL) {
        return MA_INVALID_ARGS;
    }
    delay_node_teardown(h);

    config = ma_delay_node_config_init(
        (ma_uint32)channels, (ma_uint32)sample_rate, (ma_uint32)delay_in_frames, decay);
    result = ma_delay_node_init(&g->graph, &config, NULL, &h->payload.delay);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_delay_node_uninit */
int ma_shim_delay_node_uninit(void* handle) {
    ma_shim_delay_node_state* h = (ma_shim_delay_node_state*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    delay_node_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_node_graph_get_endpoint, ma_node_attach_output_bus */
int ma_shim_delay_node_attach_to_endpoint(void* handle, void* graph_handle) {
    ma_shim_delay_node_state* h = delay_node_ready(handle);
    ma_shim_node_graph_state* g = node_graph_ready(graph_handle);
    ma_node*                  endpoint;

    if (h == NULL || g == NULL) {
        return MA_INVALID_ARGS;
    }
    endpoint = ma_node_graph_get_endpoint(&g->graph);
    if (endpoint == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_attach_output_bus((ma_node*)&h->payload.delay, 0, endpoint, 0);
}

/* @binds ma_delay_node_set_wet */
int ma_shim_delay_node_set_wet(void* handle, float value) {
    ma_shim_delay_node_state* h = delay_node_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_delay_node_set_wet(&h->payload.delay, value);
    return MA_SUCCESS;
}

/* @binds ma_delay_node_get_wet */
int ma_shim_delay_node_get_wet(void* handle, float* out_value) {
    ma_shim_delay_node_state* h = delay_node_ready(handle);
    if (out_value != NULL) { *out_value = 0; }
    if (h == NULL || out_value == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_value = ma_delay_node_get_wet(&h->payload.delay);
    return MA_SUCCESS;
}

/* @binds ma_delay_node_set_dry */
int ma_shim_delay_node_set_dry(void* handle, float value) {
    ma_shim_delay_node_state* h = delay_node_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_delay_node_set_dry(&h->payload.delay, value);
    return MA_SUCCESS;
}

/* @binds ma_delay_node_get_dry */
int ma_shim_delay_node_get_dry(void* handle, float* out_value) {
    ma_shim_delay_node_state* h = delay_node_ready(handle);
    if (out_value != NULL) { *out_value = 0; }
    if (h == NULL || out_value == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_value = ma_delay_node_get_dry(&h->payload.delay);
    return MA_SUCCESS;
}

/* @binds ma_delay_node_set_decay */
int ma_shim_delay_node_set_decay(void* handle, float value) {
    ma_shim_delay_node_state* h = delay_node_ready(handle);
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    ma_delay_node_set_decay(&h->payload.delay, value);
    return MA_SUCCESS;
}

/* @binds ma_delay_node_get_decay */
int ma_shim_delay_node_get_decay(void* handle, float* out_value) {
    ma_shim_delay_node_state* h = delay_node_ready(handle);
    if (out_value != NULL) { *out_value = 0; }
    if (h == NULL || out_value == NULL) {
        return MA_INVALID_ARGS;
    }
    *out_value = ma_delay_node_get_decay(&h->payload.delay);
    return MA_SUCCESS;
}

/* ================= ma_splitter_node ================= */

typedef ma_shim_any_node ma_shim_splitter_node_state;

static void splitter_node_teardown(ma_shim_splitter_node_state* h) {
    if (h->initialized) {
        ma_splitter_node_uninit(&h->payload.splitter, NULL);
        h->initialized = 0;
    }
}

static ma_shim_splitter_node_state* splitter_node_ready(void* handle) {
    ma_shim_splitter_node_state* h = (ma_shim_splitter_node_state*)handle;
    if (h == NULL || !h->initialized || h->kind != MA_SHIM_NODE_KIND_SPLITTER) {
        return NULL;
    }
    return h;
}

void* ma_shim_splitter_node_alloc(void) {
    ma_shim_any_node* h = (ma_shim_any_node*)calloc(1, sizeof(ma_shim_any_node));
    if (h != NULL) { h->kind = MA_SHIM_NODE_KIND_SPLITTER; }
    return h;
}

/* @binds ma_splitter_node_uninit */
void ma_shim_splitter_node_free(void* handle) {
    ma_shim_splitter_node_state* h = (ma_shim_splitter_node_state*)handle;
    if (h == NULL) {
        return;
    }
    splitter_node_teardown(h);
    free(h);
}

/* @binds ma_splitter_node_config_init, ma_splitter_node_init */
int ma_shim_splitter_node_init(void* handle, void* graph_handle, unsigned int channels) {
    ma_shim_splitter_node_state* h = (ma_shim_splitter_node_state*)handle;
    ma_shim_node_graph_state*    g = node_graph_ready(graph_handle);
    ma_splitter_node_config      config;
    ma_result                    result;

    if (h == NULL || g == NULL) {
        return MA_INVALID_ARGS;
    }
    splitter_node_teardown(h);

    config = ma_splitter_node_config_init((ma_uint32)channels);
    result = ma_splitter_node_init(&g->graph, &config, NULL, &h->payload.splitter);
    if (result == MA_SUCCESS) {
        h->initialized = 1;
    }
    return (int)result;
}

/* @binds ma_splitter_node_uninit */
int ma_shim_splitter_node_uninit(void* handle) {
    ma_shim_splitter_node_state* h = (ma_shim_splitter_node_state*)handle;
    if (h == NULL) {
        return MA_INVALID_ARGS;
    }
    splitter_node_teardown(h);
    return MA_SUCCESS;
}

/* @binds ma_node_graph_get_endpoint, ma_node_attach_output_bus */
int ma_shim_splitter_node_attach_to_endpoint(
    void* handle, unsigned int output_bus, void* graph_handle
) {
    ma_shim_splitter_node_state* h = splitter_node_ready(handle);
    ma_shim_node_graph_state*    g = node_graph_ready(graph_handle);
    ma_node*                     endpoint;

    if (h == NULL || g == NULL) {
        return MA_INVALID_ARGS;
    }
    endpoint = ma_node_graph_get_endpoint(&g->graph);
    if (endpoint == NULL) {
        return MA_INVALID_ARGS;
    }
    return (int)ma_node_attach_output_bus((ma_node*)&h->payload.splitter, (ma_uint32)output_bus, endpoint, 0);
}
