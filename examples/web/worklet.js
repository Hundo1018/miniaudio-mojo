// AudioWorklet side of the ring: drains interleaved stereo f32 frames that the
// main thread rendered with miniaudio-mojo (web_render) into a SharedArrayBuffer.
//
// Ring layout (shared with main.js):
//   ctl  = Int32Array(sab, 0, 4): [0] write index, [1] read index (frames, mod capacity),
//                                 [2] under-run count, [3] frames played
//   data = Float32Array(sab, 16, capacity * 2)
// Under-run policy: if fewer than 128 frames are buffered the block is silence,
// nothing is consumed, and ctl[2] is incremented.
// Refill: when less than half the ring is buffered the worklet posts a message,
// at most once per 8 blocks; the main thread renders on it. (requestAnimationFrame
// alone stops in a background tab; messages keep arriving.)
class RingPlayer extends AudioWorkletProcessor {
  constructor(options) {
    super();
    const { sab, capacity } = options.processorOptions;
    this.ctl = new Int32Array(sab, 0, 4);
    this.data = new Float32Array(sab, 16, capacity * 2);
    this.capacity = capacity;
    this.sinceAsk = 8;
  }

  process(inputs, outputs) {
    const out = outputs[0];
    const left = out[0];
    const right = out[1] ?? out[0];
    const frames = left.length;
    const w = Atomics.load(this.ctl, 0);
    let r = Atomics.load(this.ctl, 1);
    const available = (w - r + this.capacity) % this.capacity;
    if (available < this.capacity / 2 && ++this.sinceAsk >= 8) {
      this.port.postMessage(available);
      this.sinceAsk = 0;
    }
    if (available < frames) {
      left.fill(0);
      right.fill(0);
      Atomics.add(this.ctl, 2, 1);
      return true;
    }
    for (let i = 0; i < frames; i++) {
      left[i] = this.data[2 * r];
      right[i] = this.data[2 * r + 1];
      r = (r + 1) % this.capacity;
    }
    Atomics.store(this.ctl, 1, r);
    Atomics.add(this.ctl, 3, frames);
    return true;
  }
}

registerProcessor("ring-player", RingPlayer);
