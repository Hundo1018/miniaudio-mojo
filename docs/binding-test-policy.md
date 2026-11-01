# Binding Test-First Policy

This project follows a strict test-first workflow for binding work.

## Rule

Every new binding addition must include tests before implementation is finalized.

## Minimum requirements per binding change

1. Add at least one positive-path test.
2. Add at least one negative-path test (bad argument, wrong state, or failing input), asserting the
   `MaResult` the call returns or the `MaError.result` it raises.
3. Put the tests in `tests/test_<family>_binding.mojo` (raw layer) and
   `tests/test_<family>_api.mojo` (RAII layer); never in `src/`.
4. Wire them into a `test-<family>` task in `pixi.toml` and add that task to the `test` aggregate.
5. Mark the shim function with a single-line `/* @binds ma_... */` comment and update
   `docs/coverage-targets.json` / `docs/binding-coverage.md`.

## Gate

```bash
pixi run gate
```

`gate` runs every `test-<family>` task on the null backend (no audio device needed), then
`coverage-binding` (every shim export bound and referenced by a test, `@binds` and exclusions
valid) and `coverage-shim` (gcov line coverage of `src/native/ma_shim*.c`, at least 95%). A change
is done when `gate` is green.

## Review checklist

- [ ] Positive and negative tests are present.
- [ ] Tests are task-wired and reproducible.
- [ ] `pixi run gate` is green.
- [ ] `docs/binding-coverage.md` reflects new test scope.
