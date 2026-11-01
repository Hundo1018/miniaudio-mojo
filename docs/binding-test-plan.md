# Binding Test Architecture

## Topology

One family, two files, one task:

- `tests/test_<family>_binding.mojo`: the raw layer (`src/miniaudio/_ffi/<family>_raw.mojo`),
  called directly against the shim. Pins return codes (`MaResult`), out-values and
  null-handle / invalid-argument behaviour.
- `tests/test_<family>_api.mojo`: the RAII layer (`src/miniaudio/<family>.mojo`). Pins
  lifetimes, state transitions and the `MaError.result` each failure raises.
- `test-<family>` in `pixi.toml` builds the shim and runs both; `test` runs them all.

Shared fixtures live in `tests/support/`. Tests use the null backend, so nothing needs an audio
device. Generated assets (`pixi run gen-test-wav`) go under `build/test_assets/`.

## Coverage Levels (Binding-Focused)

- Level 0: No coverage
  - No tests for the binding family.
- Level 1: Smoke
  - Basic call-path execution and simple pass/fail checks.
- Level 2: Contract
  - Deterministic invalid-arg/null-handle/idempotency checks.
- Level 3: Behavioral
  - State transitions, cross-mode re-init, value invariants.
- Level 4: Scenario
  - Multi-component workflows (resource pipeline, graph chains, async orchestration).

Per-family levels and status are tracked in `docs/coverage-targets.json` and summarised in
`docs/binding-coverage.md`.

## Definition Of Done For A Binding Family

- Binding and API tests reach Level 2 (contract) and Level 3 (behavioral).
- Wired into `pixi run test`; `pixi run gate` green.
- Documented in `docs/binding-coverage.md`.
