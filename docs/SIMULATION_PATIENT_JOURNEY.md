# Simulation Lab — Patient Journey Evidence

## Purpose and authority

Phase 12 runs deterministic scripted journeys against the real Flutter Patient UI. `PatientHomePage`, Today, Quick Log, Timeline, Month Calendar, Connected Health, the privacy cover, production navigation, repository writes, and audit append behavior remain authoritative. The journey harness supplies only deterministic synthetic inputs and test-boundary controls; it is not a second Patient application or a pure-Dart Patient simulator.

The resulting report is synthetic pre-human engineering evidence. It establishes reachability, deterministic behavior, recovery, persistence, retrieval, and the defined safety assertions. It does not establish that a real Patient understood, trusted, easily found, or successfully completed a task.

## Canonical contract

The canonical run uses:

- seed `20260917`;
- fixed UTC virtual-now `2026-09-17T09:00:00Z`;
- locale `en`;
- synthetic fixtures `P-001`, `P-002`, and `P-005`;
- `syntheticEvidenceOnly: true`.

Its six journey families are:

1. `privacyUnlockRecovery`
2. `privacyLifecycleRelock`
3. `todayComprehensionSurface`
4. `quickLogPersistence`
5. `timelineCalendarRetrieval`
6. `connectedHealthStates`

`PatientHomePage` receives an injectable clock whose production default remains `DateTime.now`. Canonical evidence records only deterministic audit summaries such as action, count, subject type, and stable subject summary. It excludes the wall-clock audit timestamp and ID produced by `AuditEvent.now()`, as well as host paths, temporary paths, framework exception text, object identities, and screenshot metadata.

Observed, missing, conflicting, and provenance Connected Health cases use the real home route and `ConnectedHealthViewModelBuilder`. The production builder does not emit stale state, so stale presentation is exercised directly through the real `ConnectedHealthScreen` widget. The evidence preserves this `home-route` versus `direct-production-widget` distinction; the builder is not changed to manufacture stale data.

## Findings and metrics

S4 findings cover privacy disclosure or bypass, sensitive content visible while locked, missing data invented as zero, and conflicting data collapsed to certainty. S3 findings cover blocked core journeys, missing recovery, persistence or audit mismatch, timeline or calendar retrieval failure, connected-health state mismatch, malformed evidence, and mandatory coverage gaps.

Action, navigation, and recovery counts are soft metrics. They do not fail a release without a separately approved threshold. The canonical smoke fails on any finding, failed or malformed result, inconsistent configured/evaluated/passed counts, or absent mandatory coverage label.

## Run and artifact

Run locally from the repository root:

```bash
cd apps/patient
flutter pub get
flutter test test/patient_journey_smoke_test.dart
```

The smoke writes `apps/patient/patient-journey-evidence.json`. CI uploads it with the exact artifact name `simulation-patient-journey-evidence`. The generated JSON is evidence output and is not committed as source.

## Human-evidence boundary

Issues #34 and #58 remain open. Synthetic Patient Journey evidence cannot satisfy their real Patient and Doctor human-session acceptance criteria, and Phase 12 does not mark the human-usability item in `TODO.md` complete.

Phase 13 Partner Journey Lab, Phase 14 Doctor Journey Lab, Phase 15 Doctor Cognitive Load, Phase 20 Accessibility Lab breadth, Phase 34 pre-human validation rollup, and Phase 35 real human validation transition remain deferred to their own phases.
