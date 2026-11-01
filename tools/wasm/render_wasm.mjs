// Render the parity scene in a wasm64 module and write the raw f32 PCM.
//
//   node tools/wasm/render_wasm.mjs build/wasm/audio.wasm <clip file> <frames> <out.f32>
//
// Node 24 (memory64 + table64). The module imports only env.host_write, which the shared
// ludens-wasm-rt host runtime provides.
import { readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const hostPath = process.env.LUDENS_WASM_HOST;
if (!hostPath) throw new Error("LUDENS_WASM_HOST (path of ludens-wasm-rt host.mjs) is not set");
const { instantiate } = await import(pathToFileURL(hostPath));
const miniaudio = await import(pathToFileURL(resolve(import.meta.dirname, "../../web/miniaudio_host.mjs")));

const [wasmPath, clipPath, framesArg, outPath] = process.argv.slice(2);
const frames = Number(framesArg);
const rt = await instantiate(readFileSync(wasmPath), { libs: [miniaudio] });
const x = rt.exports;

const clip = readFileSync(clipPath);
const clipPtr = x.web_alloc(BigInt(clip.length));
rt.put(clipPtr, clip);
const outBytes = frames * 2 * 4;
const outPtr = x.web_alloc(BigInt(outBytes));
const t0 = performance.now();
const rc = x.web_render_scene(clipPtr, BigInt(clip.length), frames, outPtr);
const ms = performance.now() - t0;
if (rc !== 0) {
  console.error(`web_render_scene failed: ma_result ${rc}`);
  process.exit(1);
}
writeFileSync(outPath, rt.bytes(outPtr, outBytes));
console.log(`wasm: ${frames} frames in ${ms.toFixed(1)} ms, peak heap ${x.rt_peak_bytes()} bytes`);
