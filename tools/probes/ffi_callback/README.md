# FFI callback probes

Throwaway-sized programs that answer one question: can Mojo code be handed to C as a callback?
They are the evidence behind roadmap step 18 in `docs/binding-coverage.md`, which unblocked the
six `custom_callback_or_vtable_ctor` exclusions. Run them all with:

```bash
pixi run probe-ffi-callback
```

The libraries are built into `build/probes/`; `p4` also needs the test WAV (`gen-test-wav`).

| Probe | Question | Result on Mojo 1.1.0 (2026-10-08) |
|-------|----------|-----------------------------------|
| `p1.mojo` | Does a plain `def` written at the `OwnedDLHandle.call` site work as a C function pointer? | Yes: `P1 rc= 0 got= 4 buf= 7 7` |
| `p2.mojo` | Does a function *value* (`var f = fill7`) work? The 2026-05 nightly rejected this. | Yes: `P2 rc= 0 got= 1` |
| `p3.mojo` | Inside `register[S: Source]`, does the generic instance `tramp[S]` work when C stores it and calls it later, also from a C-spawned thread? Do two different `S` dispatch to their own methods? | Yes: `Counter` fills 10..13 then 14..16 from a pthread, its state advances to 17; a later `Halver` registration returns 3 of 6 bytes and leaves `Counter` untouched |
| `p4.mojo` | End to end: does `ma_decoder_init` driven by Mojo read/seek trampolines over an in-memory stream decode like `ma_decoder_init_file`? | Yes: 2 ch, 48 kHz, 48000 frames; 4800 frames at frame 0 and after `seek(24000)` match bit for bit (0 of 9600 samples differ); reading past the end returns the last 1000 frames |

`probe_cb.c` is a toy C library with the same callback shape as `ma_read_proc`
(`(user, buffer, bytes, *bytes_read) -> result`). `probe_dec.c` wraps the real `ma_decoder_init`
with C trampolines that adapt miniaudio's `(ma_decoder*, ...)` signatures to that shape — the same
adapter the bindings use.

What the probes do not cover, and the bindings must handle themselves: keeping the Mojo object
alive on the heap for as long as C holds the pointer (Mojo destroys values after their last use),
and never raising out of a trampoline.
