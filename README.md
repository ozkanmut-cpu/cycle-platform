# Cycle Platform

Privacy-first reproductive health platform with separate Patient, Partner and Doctor applications.

## Product principles

- Local-first health data ownership
- No mandatory account for core patient use
- Encrypted local vault and encrypted backups
- Granular permission graph for view, notify, backup and export
- HealthKit / Health Connect / wearable ingestion
- Explainable AI with evidence and provenance
- Doctor-in-the-loop clinical workflows
- Progressive disclosure: simple by default, clinically deep on demand
- Unknown is not the same as No
- The smarter Cycle gets, the less the user should have to log

## Apps

- `apps/patient` — Cycle Patient
- `apps/partner` — Cycle Partner
- `apps/doctor` — Cycle Doctor

## Core architecture

Shared domain and infrastructure packages live under `packages/`. Clinical definitions and versioned rules live under `clinical/`. Machine-readable schemas live under `schemas/`.

See `ARCHITECTURE.md` and `TODO.md` for the current technical plan.

## Development status

Early architecture/bootstrap phase. The repository is private and under active development.
