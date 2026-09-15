# Cycle Simulation Lab — Canonical Cohort

Phase 4 materializes the deterministic 155-actor synthetic test world used by later Cycle Simulation Lab phases. It is machine-test infrastructure, not human participant evidence.

## Canonical population

A root seed creates exactly 100 Patient, 50 Partner, and 5 Doctor personas. Actor IDs remain stable for the same seed. Every Partner is linked to one valid Patient and every Patient receives deterministic Doctor coverage. Doctor personas contain workflow traits only; assignments do not copy raw Patient health data into Doctor persona definitions.

## Coverage

The cohort deliberately includes test conditions for low health/digital literacy, accessibility needs, high privacy sensitivity, wearable-heavy and no-wearable use, sparse or dense data, prolonged/conflicting missingness, and high symptom burden. These are coverage dimensions, not demographic stereotypes or assumptions about real people.

## Permission boundaries

Cohort validation reuses persona validation. Generic sharing grants and relationship-category grants stay separate. Playful does not imply Intimacy. Intimacy remains disabled in generated Partner personas unless an explicit intimacy category grant exists.

## Determinism and validation

`SimulationCohort` uses `schemaVersion: 1`, stable JSON serialization, exact-count validation, global ID uniqueness, non-dangling relationship and doctor assignments, coverage requirements, and persona safety validation. Same seed produces canonical-equivalent output.

## Human validation boundary

This work supports pre-human validation only. Issue #58 remains open until actual Patient and Doctor usability sessions produce real human evidence. Synthetic cohort results must never be represented as human usability findings.
