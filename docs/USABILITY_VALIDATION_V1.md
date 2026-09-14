# V1 Patient and Doctor Usability Validation

This file is the reproducible evidence plan for the final V1 usability blocker. Automated checks and human-participant evidence are deliberately separated; passing widget tests is not represented as human usability research.

## Automated validation scope

### Patient critical journeys
1. Understand Today without being forced to log.
2. Open Quick Log and identify period, flow and symptom actions without advanced configuration.
3. Open Connected Health and distinguish observed, missing, stale and conflicting states.
4. Confirm empty health data remains missing rather than becoming `0` or normal.
5. Confirm privacy cover/authentication failure exposes a clear recovery action.
6. Confirm timeline/calendar retain simple-first progressive disclosure.

### Doctor critical journeys
1. Select a patient while preserving patient scope.
2. Move between What Changed, What Matters, Missing, Uncertain, Conflicts and Open Loops.
3. Confirm Doctor Review remains visible while navigating.
4. Confirm evidence/compression/reasoning/copilot panels remain present after patient/section changes.
5. Confirm primary navigation controls expose tap semantics.

Automated coverage lives in `apps/patient/test/*usability_test.dart`, existing Patient widget tests, `apps/doctor/test/doctor_shell_test.dart`, and `apps/doctor/test/doctor_usability_test.dart`.

## Human usability protocol

Human results must only be recorded after real sessions. Recommended minimum: 5 patient participants and 5 clinicians, with additional sessions until no new V1-blocking pattern appears.

### Patient script
- From first view, explain what Cycle expects you to do today.
- Record one symptom using the shortest path.
- Find connected-health data and explain what a missing or conflicting reading means.
- Find the timeline/calendar and describe what was logged.
- Encounter a locked/private state and recover access.

### Doctor script
- Open a different patient and verify whose record is active.
- Find what changed and what matters.
- Locate missing, uncertain, conflicting and open-loop information.
- Explain whether the system can write clinical conclusions without review.
- Trace from a compressed statement toward evidence/reasoning context.

## Observation rubric

For each task record: completion (success / partial / fail), time on task, wrong turns, facilitator help, comprehension errors, privacy/safety misunderstanding, accessibility barrier, and free-text observation.

Severity scale:
- S0: cosmetic only.
- S1: friction; task completes without help.
- S2: material confusion or repeated wrong turn; workaround exists.
- S3: critical journey cannot be completed or safety/privacy meaning is misunderstood.
- S4: creates realistic risk of unsafe clinical action, privacy disclosure, wrong-patient action, or fabricated certainty.

V1 release criterion: no unresolved S3/S4 defects in the tested critical journeys. S2 items require an explicit disposition.

## Evidence status

- Automated Patient usability coverage: implemented and CI-gated.
- Automated Doctor usability coverage: implemented and CI-gated.
- Human-participant sessions: **not yet performed / not claimed by this repository evidence**.

Therefore `patient and doctor usability testing` must remain unchecked until actual human sessions are completed and their anonymized aggregate findings are recorded without personal health information.
