# Cycle Simulation Lab — Synthetic Health World

Phase 5 gives every Patient in the canonical 155-actor cohort a deterministic synthetic health timeline. This is test infrastructure only: it is not medical advice, epidemiology, or evidence from real people.

## World model

`SyntheticHealthWorldGenerator` starts from a validated `SimulationCohort` and one root seed. The default world spans 28 UTC days and produces exactly one timeline for each of the 100 canonical Patients. The same cohort, seed, start instant and duration produce equivalent serialized output.

Observations carry an explicit signal kind, timestamp, source, uncertainty state, optional value and unit. Sources distinguish manual, wearable and clinical observations. The first implementation includes symptom severity, resting heart rate, sleep duration and weight signals, while the schema reserves additional signal kinds for later longitudinal and clinical-safety phases.

## Truth and uncertainty semantics

The synthetic world deliberately contains known, missing, estimated and conflicting observations. Missing observations never contain a numeric value; in particular, missing data is never encoded as zero. Conflicting observations preserve both incompatible values rather than silently choosing one. Estimated observations remain explicitly labelled as estimated.

Persona traits influence generated timelines deterministically. Sparse loggers produce gaps, prolonged-missingness personas receive a deterministic missing interval, conflicting-missingness personas receive conflicting observations, and wearable users receive device-style signals. These are synthetic stress cases and must not be interpreted as claims about real people with similar traits.

## Validation

World validation rejects duplicate Patient timelines, dangling or incomplete cohort coverage, empty timelines, non-UTC timestamps, duplicate observation IDs, out-of-order observations and invalid uncertainty/value combinations. CI runs deterministic tests plus a seeded health-world smoke command and uploads machine-readable evidence.

## Human validation boundary

Synthetic world evidence supports pre-human validation but does not satisfy Issue #58. Actual Patient and Doctor usability sessions remain required before that human-validation blocker may be completed.
