# Cycle Simulation Lab

## Purpose
Cycle Simulation Lab is pre-human validation infrastructure for deterministic synthetic scenarios, safety checks, privacy checks, and reproducible usability experiments. It supports, but never replaces, real Patient, Partner, and Doctor usability sessions.

## Evidence classes
- **Hard invariants**: safety/privacy/clinical-truth conditions that fail a run regardless of average usability score.
- **Soft scores**: usability, comprehension, interaction cost, accessibility, recovery, and similar comparative measures.
- **Human evidence**: moderated/unmoderated findings collected from real participants. Synthetic runs must never be reported as human evidence.

## Foundation contract
A simulation run is defined by a stable seed, scenario, actor set, virtual clock, totally ordered events, invariant results, and replay metadata. The same seed and scenario must produce byte-stable normalized result data when code and fixtures are unchanged.

Wall-clock time is not a simulation input. Virtual time may advance rapidly, but cannot move backwards within a run.

## Replay
Every failed run must retain enough information to replay the same execution:

`seed + scenarioId + ordered eventIds`

Later phases will extend replay metadata with cohort version, persona version, fixture version, and minimized failure traces.

## Severity
- **S0** cosmetic only
- **S1** minor friction
- **S2** material usability or comprehension problem with a safe workaround
- **S3** serious workflow, privacy, or safety defect that blocks V1 until resolved or explicitly dispositioned
- **S4** critical safety/privacy/clinical-truth failure; always a hard release failure

## Initial hard invariants
The foundation starts with deliberately small generic contracts:
- missing data must not be converted to numeric zero;
- access at or after a recorded revocation boundary must fail.

Production-domain permission and clinical semantics remain authoritative. Simulation invariants test observable contracts and should not duplicate production business logic where a production engine can be invoked directly.

## Roadmap boundary
Phase 0 and Phase 1 provide only the deterministic simulation substrate. Persona generation, the 100 Patient + 50 Partner + 5 Doctor golden cohort, health-world generation, clinical oracle depth, UI journeys, chaos, red-team, mutation testing, and human usability sessions are later phases.

## Foundation smoke run
From `packages/simulation_domain`:

```bash
dart pub get
dart run bin/foundation_smoke.dart --seed=20260914
```

The command prints normalized JSON suitable for CI capture and replay diagnostics.
