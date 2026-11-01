import { instantiate } from "./host.mjs"; // ludens-wasm-rt's shared runtime
import * as miniaudio from "./miniaudio_host.mjs";

// Main thread: owns the wasm64 module (miniaudio-mojo, built by the ludens-wasm-rt driver),
// renders 128-frame blocks with web_render, and keeps the AudioWorklet's
// SharedArrayBuffer ring ~TARGET_FRAMES ahead of playback (see worklet.js).
const SAMPLE_RATE = 48000;
const CAPACITY = 8192; // ring size in frames
const TARGET_FRAMES = 6144; // how far ahead to render (~128 ms)
const BLOCK = 128;

const stats = { started: false, rendered: 0, played: 0, underruns: 0, rms: 0, clip: "none", error: "" };
window.maStats = stats; // for automated checks

let rt, x, memory, scene, ring, ctl, ctx, analyser;

async function loadModule() {
  rt = await instantiate(fetch("audio.wasm"), { libs: [miniaudio] });
  x = rt.exports;
  memory = rt.memory;
  scene = x.web_create(SAMPLE_RATE);
  if (!scene) throw new Error("web_create failed");
}

function fill() {
  const w0 = Atomics.load(ctl, 0);
  const r = Atomics.load(ctl, 1);
  let buffered = (w0 - r + CAPACITY) % CAPACITY;
  let w = w0;
  while (buffered + BLOCK <= TARGET_FRAMES) {
    const ptr = x.web_render(scene, BLOCK);
    if (!ptr) throw new Error("web_render failed");
    const block = rt.f32(ptr, BLOCK * 2); // memory may have grown
    for (let i = 0; i < BLOCK; i++) {
      ring[2 * w] = block[2 * i];
      ring[2 * w + 1] = block[2 * i + 1];
      w = (w + 1) % CAPACITY;
    }
    buffered += BLOCK;
    stats.rendered += BLOCK;
  }
  Atomics.store(ctl, 0, w);
}

function fillSafely() {
  try {
    fill();
  } catch (e) {
    stats.error = String(e);
  }
}

function frame() {
  try {
    fill(); // once per animation frame: the game loop's frame() in a real app
    stats.played = Atomics.load(ctl, 3);
    stats.underruns = Atomics.load(ctl, 2);
    const buf = new Float32Array(analyser.fftSize);
    analyser.getFloatTimeDomainData(buf);
    stats.rms = Math.sqrt(buf.reduce((a, v) => a + v * v, 0) / buf.length);
    document.getElementById("stats").textContent =
      `played ${stats.played} frames, rendered ${stats.rendered}, under-runs ${stats.underruns}, ` +
      `output RMS ${stats.rms.toFixed(3)}, clip: ${stats.clip}`;
    requestAnimationFrame(frame);
  } catch (e) {
    stats.error = String(e);
    document.getElementById("stats").textContent = "error: " + e;
  }
}

async function loadClip(bytes, name) {
  const p = x.web_alloc(BigInt(bytes.length));
  rt.put(p, bytes);
  const rc = x.web_load_clip(scene, p, BigInt(bytes.length));
  x.web_free(p);
  stats.clip = rc === 0 ? name : `failed (ma_result ${rc})`;
}

function setTone() {
  const hz = Number(document.getElementById("hz").value);
  const gain = Number(document.getElementById("gain").value);
  document.getElementById("tone").textContent = `${hz} Hz, gain ${gain}`;
  x.web_set_tone(scene, hz, gain);
}

async function start() {
  if (stats.started) return;
  if (!crossOriginIsolated) throw new Error("not cross-origin isolated: serve with examples/web/serve.py");
  await loadModule();
  const sab = new SharedArrayBuffer(16 + CAPACITY * 2 * 4);
  ctl = new Int32Array(sab, 0, 4);
  ring = new Float32Array(sab, 16, CAPACITY * 2);
  ctx = new AudioContext({ sampleRate: SAMPLE_RATE }); // a user gesture got us here
  await ctx.audioWorklet.addModule("worklet.js");
  const node = new AudioWorkletNode(ctx, "ring-player", {
    outputChannelCount: [2],
    processorOptions: { sab, capacity: CAPACITY },
  });
  node.port.onmessage = fillSafely; // the worklet asks when the ring runs low
  analyser = ctx.createAnalyser();
  analyser.fftSize = 2048;
  node.connect(analyser).connect(ctx.destination);
  setTone();
  fill(); // prime the ring before the worklet starts pulling
  stats.started = true;
  requestAnimationFrame(frame);
}

document.getElementById("start").onclick = () => start().catch((e) => (stats.error = String(e)));
document.getElementById("hz").oninput = () => scene && setTone();
document.getElementById("gain").oninput = () => scene && setTone();
document.getElementById("clip").onclick = async () =>
  loadClip(new Uint8Array(await (await fetch("clip.wav")).arrayBuffer()), "clip.wav");
document.getElementById("file").onchange = async (e) => {
  const f = e.target.files[0];
  if (f) loadClip(new Uint8Array(await f.arrayBuffer()), f.name);
};

// ?selftest: start without a click (only where autoplay is allowed, e.g. a test
// browser profile), play the clip, and POST the counters to serve.py's /report.
async function selftest() {
  const sample = () => ({ ...stats, ua: navigator.userAgent });
  try {
    await start();
    await new Promise((r) => setTimeout(r, 1500));
    const toneOnly = sample();
    await loadClip(new Uint8Array(await (await fetch("clip.wav")).arrayBuffer()), "clip.wav");
    await new Promise((r) => setTimeout(r, 400));
    const withClip = sample();
    await fetch("report", { method: "POST", body: JSON.stringify({ toneOnly, withClip, ctxState: ctx.state }) });
  } catch (e) {
    await fetch("report", { method: "POST", body: JSON.stringify({ error: String(e), stats: sample() }) });
  }
}
if (new URLSearchParams(location.search).has("selftest")) selftest();
