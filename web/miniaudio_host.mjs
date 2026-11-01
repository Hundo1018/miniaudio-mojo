// miniaudio-mojo's contribution to a wasm module's importObject.
//
// The module needs no host imports of its own (the shared runtime supplies env.host_write),
// so this returns an empty object. It exists so that several libraries' JS glue can be merged
// into one importObject by ludens-wasm-rt's host.mjs: pass this module in `libs`.
export function createImports(rt) {
  return {};
}
