# Cycle Simulation Lab — Persona Domain

Phase 3 defines deterministic synthetic actors for machine testing. These personas are test fixtures, not claims about real patients, partners, clinicians, age groups, diagnoses, cultures, or demographic behaviour. Human usability evidence remains separate and is still required by #58.

## Shared model

Every persona has a stable role and ID plus age, health literacy, digital literacy, accessibility needs, privacy sensitivity, data density, wearable use, logging behaviour, goals, fears, and an expected mental model. Traits describe a test condition; they must not be used as a proxy for clinical truth or permissions.

## Patient

Patient personas add cycle/life stage, conditions, medications, symptom burden, missingness pattern, and health-data sources. Missingness is explicit and never means zero or normal. Wearable use requires an explicit source.

## Partner

Partner personas add relationship type, generic sharing grants, relationship-category grants, Playful preference, intimacy preference, and boundary sensitivity. Generic sharing and relationship categories remain distinct. Intimacy cannot be enabled without an explicit intimacy category grant.

## Doctor

Doctor personas add specialty profile, caseload pressure, risk tolerance, and review style. These dimensions model workflow pressure and information presentation preferences; they do not alter clinical evidence or ground truth.

## Determinism and schema

Persona JSON uses `schemaVersion: 1`. Unknown versions are rejected. The seeded generator produces stable role IDs and values for the same seed. JSON round-trip tests ensure semantic preservation. Later cohort work will layer stratified and risk-weighted coverage on top of these primitives rather than encoding demographic stereotypes into the generator.

## CI

`Simulation Lab` runs persona tests and `persona_smoke.dart`. The smoke command emits a machine-readable Patient + Partner + Doctor fixture artifact named `simulation-persona-fixtures`.
