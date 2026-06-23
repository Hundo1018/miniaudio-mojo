# Binding Test-First Policy

This project follows a strict test-first workflow for binding work.

## Rule

Every new binding addition must include tests before implementation is finalized.

## Minimum requirements per binding change

1. Add at least one positive-path test.
2. Add at least one negative-path test.
3. Place Mojo test modules under `tests/` (do not mix test code into `src/api`).
4. Wire tests into runnable tasks (`pixi.toml`).
4. Update coverage tracking docs (`docs/binding-coverage.md`).
5. Ensure no regression in existing smoke tasks.

## Native first safety gate

Before editing wrapper internals for a new binding slice, run:

```bash
pixi run smoke-native-binding-suite
```

This suite is hardware-independent and validates key shim smoke helpers.

## Coverage baseline gate

After tests are added, regenerate baseline coverage:

```bash
pixi run coverage-native-baseline
pixi run coverage-native-summary
```

If coverage regresses for binding-owned files, the change is not ready.

For an urgent one-command gate, run:

```bash
pixi run gate-binding-test-first
```

This executes native binding suite first, then regenerates coverage summary.

For Mojo-side binding verification, run:

```bash
pixi run gate-binding-test-first-mojo
```

This executes a deterministic Mojo suite with baseline playback smoke disabled.

## Review checklist

- [ ] Positive and negative tests are present.
- [ ] Tests are task-wired and reproducible.
- [ ] Coverage artifacts are regenerated.
- [ ] `docs/binding-coverage.md` reflects new test scope.
