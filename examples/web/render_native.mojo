"""Render the parity scene natively and write the raw f32 PCM (the reference the
wasm module must match byte for byte).

    mojo build --target-cpu x86-64 -D MINIAUDIO_LINK=static -I src -I examples/web \\
        examples/web/render_native.mojo -o build/wasm/render_native -Xlinker build/libma_shim.a ...
    build/wasm/render_native <clip file> <frames> <out.f32>
"""

from std.sys import argv

from scene import render_scene


def main() raises:
    var args = argv()
    var clip: List[UInt8]
    with open(String(args[1]), "r") as f:
        clip = f.read_bytes()
    var pcm = render_scene(clip, Int(String(args[2])))
    var bytes = List[UInt8](capacity=len(pcm) * 4)
    var p = pcm.unsafe_ptr().unsafe_bitcast[UInt8]()
    for i in range(len(pcm) * 4):
        bytes.append(p[i])
    with open(String(args[3]), "w") as f:
        f.write_bytes(bytes)
    print("native:", len(pcm) // 2, "frames")
