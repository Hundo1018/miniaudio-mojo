# Binding Test Architecture And Coverage Plan

## Goals

- Avoid monolithic test files and organize by contract domain.
- Move beyond smoke-only checks by adding deterministic contract suites.
- Track binding coverage maturity per module family, not just aggregate gcov %. 

## Test Topology

- `tests/miniaudio_contract_assertions.mojo`
  - Shared assertions (`expect_nonzero`, `expect_negative`, `expect_zero`, `expect_equal_int`).
- `tests/miniaudio_binding_contract_core.mojo`
  - Cross-surface null-handle and invalid-state bridge contracts.
- `tests/miniaudio_device_init_ex_contract.mojo`
  - Deterministic contract checks for `device_init_*_ex_f32` (argument boundaries + re-init semantics).
- `tests/miniaudio_decoder_encoder_contract.mojo`
  - Deterministic decoder/encoder contracts (invalid args/states + asset-backed positive invariants).
- `tests/miniaudio_handle_lifecycle_contract.mojo`
  - Wrapper lifecycle and idempotent close/uninit behavior.
- `tests/miniaudio_binding_contract.mojo`
  - Facade export file to preserve stable imports for `main.mojo`.

## Gate Mapping

- `pixi run gate-binding-test-first`
  - Native suite + native coverage baseline.
- `pixi run gate-binding-test-first-mojo`
  - Runs the Mojo suite with:
    - `MINIAUDIO_BINDING_CONTRACT_SMOKE=1`
    - `MINIAUDIO_HANDLE_LIFECYCLE_CONTRACT_SMOKE=1`
    - `MINIAUDIO_DEVICE_INIT_EX_CONTRACT_SUITE=1`
    - `MINIAUDIO_DECODER_ENCODER_CONTRACT_SUITE=1`

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

## Current Binding Coverage Targets

- Device `init_ex` family (`playback/capture/duplex`): target Level 3
  - Status: Level 3 in Mojo contract suite + native opportunistic path checks.
- Resource manager pipeline paths: target Level 3
  - Status: Level 2-3 mixed; requires more deterministic transition assertions.
- Decoder/encoder matrix paths: target Level 3
  - Status: Level 3 baseline with dedicated contract suite plus matrix smoke coverage.
- Node/effect graph family: target Level 3
  - Status: Level 2; mainly smoke and null/invalid wrappers.

## Next Planned Expansions

1. Add `tests/miniaudio_resource_manager_contract.mojo`
   - Deterministic result-state contracts (`result`, `wait_result`, loop/range invariants).
2. Add `tests/miniaudio_decoder_encoder_contract.mojo`
   - Format matrix invariants, invalid-state write/read contracts, repeated uninit semantics.
3. Add `tests/miniaudio_node_graph_contract.mojo`
   - Attach/detach state contracts and node endpoint invariants.
4. Add per-suite env flags and include them in `run-mojo-binding-suite`.

## Definition Of Done For A Binding Family

- At least one Level 2 deterministic contract suite.
- At least one Level 3 behavioral suite for state transitions.
- Included in Mojo gate task and passing on Linux CI-like runs.
- Documented in `docs/binding-coverage.md` and this plan.
