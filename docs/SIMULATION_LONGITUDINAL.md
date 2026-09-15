# Simulation Lab — Longitudinal Simulation

Phase 6 extends the deterministic synthetic health world into accelerated 1, 3 and 5 year trajectories.

## Purpose

The engine creates reproducible coarse-grained epochs rather than materializing every daily signal. Each canonical Patient receives exactly one trajectory. Epochs model stable periods, drift, step changes, recovery and regression, while preserving missing, estimated and conflicting data semantics and deterministic source transitions.

## Safety semantics

- Missing data is absence, never numeric zero.
- Conflicting data retains two distinct values and is never silently resolved.
- All temporal boundaries are UTC and epochs may not overlap.
- Canonical cohort validation requires exactly one trajectory for every Patient.
- Persona attributes influence only synthetic test behavior. They are not demographic or clinical claims about real people.

## Determinism and evidence

For a fixed cohort, health world, seed and horizon, normalized JSON is reproducible. Stable IDs and ordering make failures replayable. The smoke command exercises all supported horizons and emits machine-readable coverage evidence:

```sh
dart run bin/longitudinal_smoke.dart --seed=20260915
```

Coverage includes patient and epoch counts, every temporal pattern, known/missing/estimated/conflicting states, and source transitions.

## Validation boundary

This is synthetic engineering evidence. It does not demonstrate clinical efficacy, clinical safety in real-world use, or human usability. Issue #58 remains the human Patient/Doctor usability validation blocker and must not be closed or marked complete from Simulation Lab results.
