// Render the parity scene in a wasm64 module and write the raw f32 PCM.
//
//   node tools/wasm/render_wasm.mjs build/wasm/audio.wasm <clip file> <frames> <out.f32>
//
// Node 24 (memory64 + table64). The module imports only env.host_write.
import { readFileSync, writeFileSync } from "node:fs";

const [wasmPath, clipPath, framesArg, outPath] = process.argv.slice(2);
const frames = Number(framesArg);
let memory;
const decoder = new TextDecoder();
const env = {
  host_write: (fd, ptr, len) => {
    const text = decoder.decode(new Uint8Array(memory.buffer, Number(ptr), Number(len)));
    (Number(fd) === 2 ? process.stderr : process.stdout).write(text);
  },
};
const { instance } = await WebAssembly.instantiate(readFileSync(wasmPath), { env });
const x = instance.exports;
memory = x.memory;

const clip = readFileSync(clipPath);
const clipPtr = x.web_alloc(BigInt(clip.length));
new Uint8Array(memory.buffer, Number(clipPtr), clip.length).set(clip);
const outBytes = frames * 2 * 4;
const outPtr = x.web_alloc(BigInt(outBytes));
const t0 = performance.now();
const rc = x.web_render_scene(clipPtr, BigInt(clip.length), frames, outPtr);
const ms = performance.now() - t0;
if (rc !== 0) {
  console.error(`web_render_scene failed: ma_result ${rc}`);
  process.exit(1);
}
writeFileSync(outPath, new Uint8Array(memory.buffer, Number(outPtr), outBytes));
console.log(`wasm: ${frames} frames in ${ms.toFixed(1)} ms, peak heap ${x.rt_peak_bytes()} bytes`);
