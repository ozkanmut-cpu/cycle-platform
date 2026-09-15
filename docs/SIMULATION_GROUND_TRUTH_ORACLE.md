# Simulation Lab — Ground-Truth Oracle

Phase 7 adds a deterministic, synthetic-only oracle for checking Cycle simulation outputs against explicit hidden truth.

## Boundaries

The oracle is test infrastructure. It is not a clinical decision system, does not establish medical truth, and does not replace Patient or Doctor human usability validation. Issue #58 must remain open until real human sessions satisfy its acceptance criteria.

## Truth versus observation

`GroundTruthClaim` is the hidden expected state. `OracleObservation` is what a downstream system surfaced. They are separate types and are compared only by patient, signal and UTC instant. Missing, estimated and conflicting states remain first-class states rather than being inferred from numeric values.

The oracle emits deterministic findings when missing data is surfaced as known/normal, conflicting data is surfaced as certain, or estimated data is surfaced as known. Competing known truth claims at the same patient/signal/time with different values are reported as contradictions with both truth IDs retained.

## Temporal truth and provenance

Phase 6 epochs are converted to immutable temporal truth entries retaining patient ID, epoch ID, UTC bounds, pattern, state and source. Stable, drift, step-change, recovery and regression patterns remain machine-readable. Coverage also records source transitions.

## Determinism and coverage

Canonical evaluation validates the cohort, health world and longitudinal inputs, requires exact patient linkage, sorts the 100 Patient IDs and temporal truth deterministically, and emits schema-versioned normalized JSON. Coverage records evaluated patients/epochs, missing, estimated, conflicting, temporal changes, recoveries, contradictions and source transitions.

`GroundTruthReport.fromJson` rejects unsupported schema versions and malformed structures. Tests cover same-input equivalence, JSON round-trip, deliberate semantic collapse, contradiction provenance, all 100 canonical Patients, UTC and malformed input handling.

## CI evidence

Run:

```sh
dart run bin/oracle_smoke.dart --seed=20260916
```

Simulation Lab CI writes `oracle-evidence.json` and uploads it as `simulation-oracle-evidence`. The JSON explicitly carries `syntheticEvidenceOnly: true` so it cannot be confused with human or clinical evidence.
