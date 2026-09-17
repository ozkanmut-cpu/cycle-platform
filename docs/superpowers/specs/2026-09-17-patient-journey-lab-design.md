# Phase 12 — Patient Journey Lab Design

Date: 2026-09-17
Status: approved architecture, pending written-spec review
Issue: #230
Branch: `phase-12-patient-journey-lab`
Base main SHA: `e32fd24c79167ab37b63c37cf565c25243e436eb`

## 1. Goal

Phase 12 adds a deterministic Patient Journey Lab to Cycle Simulation Lab.

The lab executes scripted synthetic journeys against the real Flutter Patient application surfaces and emits canonical machine-readable evidence describing whether critical Patient journeys remain safe, reachable, recoverable, and internally consistent.

The lab is not a second Patient application, a copied navigation model, a synthetic comprehension engine, or human usability research. Production Patient widgets, navigation, repository writes, audit behavior, privacy cover, Connected Health aggregation, timeline, calendar, and Quick Log behavior remain authoritative.

All Phase 12 evidence is synthetic engineering evidence only. It must not close Issues #34 or #58 and must not mark the final human-usability TODO complete.

## 2. Existing Patient authority reused

Phase 12 exercises the existing production Patient surfaces directly:

- `PatientHomePage`
- `showQuickLogSheet`
- `PatientTimelineView`
- `MonthCalendar`
- `ConnectedHealthScreen`
- `ConnectedHealthViewModelBuilder`
- `AppLockService`
- `PatientVaultSession`
- production `HealthEventRepository` behavior exposed through the Patient session
- production audit append behavior invoked by Quick Log
- `CycleTimeline`
- Patient localization strings and real Flutter semantics

The existing Patient tests already validate several isolated surfaces, including Quick Log clarity, Connected Health missing/conflicting states, and opening Connected Health from `PatientHomePage`. Phase 12 composes these real surfaces into deterministic end-to-end journey contracts rather than replacing them with a parallel simulation.

## 3. Non-goals

Phase 12 does not implement:

- new Patient product features merely to make a journey pass;
- a second navigation/router model for Patient;
- simulated claims that a human understood a screen;
- real participant usability sessions;
- Phase 13 Partner Journey Lab;
- Phase 14 Doctor Journey Lab;
- Phase 15 Doctor Cognitive Load;
- Phase 20 full Accessibility Lab breadth;
- Phase 34 pre-human validation rollup;
- Phase 35 real human validation transition;
- broad emulator/device-farm coverage unless a required Phase 12 boundary cannot be exercised with deterministic Flutter widget tests;
- screenshot-diff or visual-regression infrastructure as a substitute for semantic assertions;
- production PHI or real participant records.

If Phase 12 discovers a real Patient defect, that defect must be fixed explicitly in the authoritative Patient production code and covered by a focused Patient regression test. The journey harness must not hide the defect by adding alternate behavior.

## 4. Design approach

Phase 12 uses a dedicated Flutter Patient journey harness.

Each journey pumps the real Patient widget tree and controls only external test boundaries:

- deterministic UTC clock;
- synthetic repository contents;
- deterministic app-lock outcomes;
- deterministic vault/session state;
- synthetic audit sink;
- fixed locale and viewport where needed.

The harness performs real UI interactions through `WidgetTester`: tap, scroll, lifecycle transitions, route navigation, sheet interaction, and visible/semantic assertions.

The harness never computes what the Patient UI should display by reproducing production business rules. It supplies fixtures, performs actions, and observes the real app.

## 5. Minimal production clock seam

`PatientHomePage` currently reads wall-clock time directly for Quick Log timestamps and cycle-day presentation. Byte-stable journey evidence requires a stable clock.

Add one minimal production seam only if implementation confirms it is required:

- optional `DateTime Function() now` (or equivalently small Patient clock interface) on `PatientHomePage`;
- default production implementation remains `DateTime.now`;
- all existing callers remain source-compatible;
- the injected clock is used only where `PatientHomePage` currently reads current time for journey-relevant behavior.

The seam must not change production time semantics. It exists only to make the existing semantics controllable in deterministic tests.

## 6. Test-infrastructure model

Journey/evidence types live under `apps/patient/test/support/` and are not exported as production Patient APIs.

### `PatientJourneyFamily`

Stable families:

- `privacyUnlockRecovery`
- `privacyLifecycleRelock`
- `todayComprehensionSurface`
- `quickLogPersistence`
- `timelineCalendarRetrieval`
- `connectedHealthStates`

### `PatientJourneyScenario`

Fields:

- stable journey ID;
- schema version;
- stable seed;
- fixed UTC virtual-now;
- synthetic fixture ID;
- locale;
- journey family;
- ordered scripted action descriptors;
- required assertion IDs;
- expected recovery affordance IDs where relevant;
- risk tags.

The scenario describes what the test driver does. It does not encode copied production display decisions.

### `PatientJourneyObservation`

Normalized observation fields may include:

- route/surface reached;
- visible semantic labels/assertion IDs satisfied;
- repository event count delta;
- persisted event ID/type/value/severity summary where non-sensitive and deterministic;
- audit action count/type summary;
- timeline/calendar retrieval observed;
- privacy cover visible/not visible;
- sensitive marker visible/not visible while covered;
- connected-health state labels observed;
- action count;
- navigation-transition count;
- recovery-step count;
- stable failure category when an action cannot complete.

Observations must avoid screenshots, host paths, framework stack traces, random IDs, wall-clock timestamps, and environment-specific text.

### `PatientJourneyFinding`

Fields:

- stable finding category;
- severity;
- journey ID;
- assertion ID;
- stable reason code;
- deterministic diagnostics.

### `PatientJourneyCoverage`

Tracks:

- configured/evaluated/pass/fail/malformed counts;
- all six journey families;
- privacy locked/unlocked/recovery/lifecycle coverage;
- Today known/unknown cycle-day coverage;
- Quick Log persistence and audit coverage;
- timeline and calendar retrieval coverage;
- Connected Health observed/missing/stale/conflicting/provenance coverage;
- positive and negative controls;
- locale coverage used by canonical smoke;
- synthetic fixture IDs represented.

### `PatientJourneyReport`

Contains:

- schema version;
- seed;
- fixed UTC provenance;
- stable sorted journey results;
- coverage;
- soft interaction metrics;
- pass/fail summary;
- `syntheticEvidenceOnly: true`.

JSON field order and list order must be canonical.

## 7. Canonical journey families

### A. Privacy unlock and recovery

Controls and journeys:

- successful initial authentication opens the real Patient home;
- failed authentication keeps the privacy cover active;
- failed authentication exposes a clear real recovery action;
- recovery authentication opens the same production home without bypassing the session boundary.

Hard containment:

- sensitive fixture content must never appear while the privacy cover is active;
- a missing recovery affordance on the blocked core journey is an S3 finding;
- sensitive-content exposure while locked is S4.

### B. Background/foreground privacy relock

Journey:

- open the real Patient home with synthetic sensitive content;
- transition lifecycle away from resumed according to production behavior;
- verify privacy cover becomes active and sensitive markers are not exposed;
- resume and follow production re-authentication behavior;
- verify recovery/unlock restores the real home only after authentication.

Sensitive-content exposure while covered is S4.

### C. Today comprehension surface

Journeys cover observable presentation only, not human comprehension claims:

- Today surface is reachable without forcing a log action;
- unknown cycle day remains explicitly unknown rather than invented;
- known cycle-day fixture produces the production cycle-day surface;
- the real affordances for calendar, Quick Log, Connected Health, and encrypted vault are discoverable through visible/semantic labels.

Phase 12 may assert that explanatory copy/affordances are present. It must not report that a human understood them.

### D. Quick Log -> persistence -> audit/reload -> timeline

Journey:

- start from real Patient home;
- open real Quick Log;
- choose one canonical event through the real sheet;
- allow production `_logSelection` flow to create the event;
- observe repository persistence;
- observe audit append;
- observe home reload;
- verify the newly logged event is visible through the real timeline surface.

The deterministic clock must make the created event identity/timestamps stable if those values are included in evidence.

The journey harness must not insert the event directly when validating this path.

### E. Timeline/calendar prior-event retrieval

Journeys:

- preload deterministic synthetic prior events;
- verify the real home timeline exposes prior history;
- open the real calendar affordance;
- navigate/scroll only through production UI;
- verify canonical prior-event markers are retrievable;
- preserve simple-first progressive disclosure rather than requiring advanced configuration before basic retrieval.

Phase 12 measures reachability and interaction cost. It does not infer human preference.

### F. Connected Health states

Use real `ConnectedHealthViewModelBuilder` and `ConnectedHealthScreen` through the Patient home route where feasible.

Canonical states:

- observed value with provenance/source label;
- missing/empty data;
- stale data where production model supports it;
- conflicting sources;
- provenance/source visibility.

Hard containment:

- absence must never become numeric `0` or a fabricated normal value;
- conflicting sources must remain visibly conflicting;
- privacy-covered state must not expose connected-health detail.

Missing-as-zero or fabricated certainty is S4.

## 8. Synthetic fixtures

Phase 12 reuses the existing repository usability synthetic-data contract rather than inventing real-person-like records.

Canonical Phase 12 fixtures derive from:

- P-001 routine cycle logging;
- P-002 incomplete/conflicting data;
- P-005 privacy/lock flow.

Implementation may encode focused deterministic `HealthEvent` fixture builders in Patient test support, but identifiers must remain synthetic and stable and must preserve UNKNOWN / NOT_RECORDED / conflicting distinctions where represented.

No production PHI, names, dates of birth, addresses, phone numbers, MRNs, or participant-created records enter canonical CI evidence.

## 9. Severity and findings

Stable finding categories:

- `privacy_cover_bypass` — S4;
- `sensitive_content_exposed_while_locked` — S4;
- `missing_data_invented_as_zero` — S4;
- `conflict_collapsed_to_certainty` — S4;
- `core_journey_blocked` — S3;
- `recovery_affordance_missing` — S3;
- `persistence_mismatch` — S3;
- `audit_mismatch` — S3;
- `timeline_retrieval_failure` — S3;
- `calendar_retrieval_failure` — S3;
- `connected_health_state_mismatch` — S3 unless it fabricates certainty, which is S4;
- `malformed_input` — failing evidence;
- `coverage_gap` — failing evidence.

Soft observations such as action count, navigation count, backtracks represented by the script, or recovery-step count are not release failures by themselves unless a separate explicit threshold is approved later.

## 10. Determinism

The same code, validated fixture set, locale, seed, and fixed UTC virtual-now must produce byte-identical normalized evidence.

Forbidden canonical evidence inputs include:

- wall-clock time;
- random UUIDs;
- framework-generated object identities;
- host paths;
- temporary directories;
- process IDs;
- unordered collection traversal;
- raw Flutter exception stack traces;
- screenshot bytes;
- device-specific dimensions unless explicitly normalized.

Results sort by stable journey ID and stable assertion IDs.

If production creates an ID from the injected current time, the fixed clock makes that ID deterministic for the canonical journey.

## 11. Malformed input and fail-closed behavior

Malformed scenario schema, blank IDs, non-UTC virtual-now, duplicate action IDs, unsupported journey family, invalid fixture reference, impossible scripted action sequence, or missing required assertion IDs must produce deterministic failing `malformed_input` evidence.

The canonical smoke must not silently skip malformed journeys.

Unexpected test-driver exceptions must be normalized to stable failure codes without embedding host-specific stack paths in the canonical JSON.

## 12. Coverage gates

The canonical Patient Journey evidence fails if any mandatory dimension has zero coverage.

Mandatory positive coverage:

- all six journey families;
- successful unlock and failed-auth recovery;
- background/foreground relock;
- privacy-covered sensitive-content negative assertion;
- Today with known cycle day;
- Today with unknown cycle day;
- Quick Log persistence;
- Quick Log audit append;
- post-log timeline visibility;
- prior-event timeline retrieval;
- prior-event calendar retrieval;
- Connected Health observed;
- Connected Health missing;
- Connected Health stale where production supports it;
- Connected Health conflicting;
- Connected Health provenance/source visibility;
- safe controls and negative controls;
- P-001, P-002, and P-005 synthetic fixture coverage.

Coverage counts do not establish success. Every journey must also satisfy its assertions.

## 13. Journey harness responsibilities

Create focused support units under `apps/patient/test/support/` rather than one large test file.

Expected responsibilities:

- deterministic synthetic repository/session fixture;
- deterministic app-lock fixture with ordered authentication outcomes;
- deterministic audit fixture;
- fixed clock fixture;
- Patient app/widget bootstrap helper with real localization delegates;
- action driver helpers that use `WidgetTester` against real controls;
- canonical scenario definitions;
- report builder/canonical serializer;
- evidence writer used only by the dedicated smoke test.

Each helper must have one clear responsibility and must not duplicate production UI/business logic.

## 14. Evidence execution

Because the critical surface is Flutter UI, Phase 12 evidence is produced by `flutter test`, not by a pure-Dart simulator.

Add a dedicated smoke/evidence test, for example:

`apps/patient/test/patient_journey_smoke_test.dart`

The exact implementation name may differ, but the contract is fixed:

- it executes only production-UI Patient journeys;
- it builds the canonical report from actual widget observations;
- it writes canonical JSON to a deterministic repository-relative path such as `patient-journey-evidence.json`;
- it fails the Flutter test process on S3/S4 findings, malformed input, coverage gaps, or unexpected execution failure;
- it never writes human-usability claims.

A separate test-only evidence writer may be used to avoid mixing file I/O with journey observation logic.

## 15. Simulation Lab CI

Extend `.github/workflows/simulation-lab.yml` with a separate Flutter job named `patient-journey`.

Do not add Flutter UI execution to the existing pure-Dart `foundation` job.

The Patient journey job must:

1. checkout the exact commit;
2. set up Flutter using the same compatible toolchain conventions as repository CI;
3. resolve Patient dependencies;
4. run focused Patient journey format/analyze checks for files in scope;
5. run the canonical Patient journey smoke/evidence test;
6. run relevant Patient regression tests required by the touched production seam;
7. upload exact artifact `simulation-patient-journey-evidence`;
8. fail if the evidence file is missing.

Simulation Lab trigger paths must include:

- `apps/patient/**`;
- the Patient Journey design/documentation paths needed by Phase 12;
- `.github/workflows/simulation-lab.yml`.

The existing pure-Dart Simulation Lab job remains unchanged except for trigger/document references required to coexist with Phase 12.

## 16. Artifact contract

Exact artifact name:

`simulation-patient-journey-evidence`

The artifact contains canonical JSON with at least:

- `schemaVersion`;
- `seed`;
- fixed UTC provenance;
- `syntheticEvidenceOnly: true`;
- configured/evaluated/pass/fail/malformed counts;
- journey-family coverage;
- fixture coverage;
- privacy/recovery coverage;
- Connected Health state coverage;
- ordered result summaries;
- soft interaction metrics;
- stable findings.

The artifact must not contain screenshots, real participant data, raw sensitive fixture payloads beyond the minimum normalized assertions, or claims of observed human understanding.

## 17. Testing strategy

Implementation follows TDD.

Required test layers:

1. model/serialization tests for canonical evidence and malformed input;
2. harness-fixture tests for deterministic auth/session/audit/clock behavior;
3. focused widget journey tests for each family;
4. detector/finding self-tests that prove hypothetical S3/S4 observations fail correctly;
5. same-seed byte-stability test;
6. coverage-gap test;
7. existing Patient regression tests, especially current usability, Quick Log, timeline/calendar, Connected Health, and home-connected-health tests;
8. full repository CI on the exact feature SHA;
9. Simulation Lab Patient Journey job/artifact verification on the exact feature SHA;
10. guarded merge followed by exact merge-SHA CI and artifact verification.

If a production defect is discovered, use a focused production regression test before changing production code.

## 18. Human-evidence boundary

Phase 12 can establish that scripted synthetic journeys are reachable, deterministic, recoverable, and free of the defined hard failures.

It cannot establish that a real Patient:

- understood the interface;
- found it easy;
- trusted it appropriately;
- interpreted privacy correctly in natural use;
- completed tasks without researcher influence;
- met a human task-completion target.

Those remain real-human usability questions.

Issues #34 and #58 must remain open. Their human-session acceptance criteria remain unchecked. `patient and doctor usability testing` in `TODO.md` remains unchecked.

## 19. Completion gate

Phase 12 is complete only when all of the following are true:

- Issue #230 acceptance criteria are satisfied;
- all canonical Patient journey families and mandatory coverage dimensions are present;
- the exact feature SHA has successful full repository CI;
- the exact feature SHA has successful Simulation Lab Patient Journey evidence;
- artifact content is validated and `syntheticEvidenceOnly=true`;
- review finds no unresolved important blocker;
- the remote feature tree matches the locally verified candidate tree;
- the PR is merged with exact-head protection;
- the exact merge SHA has successful full repository CI;
- the exact merge SHA has successful Simulation Lab Patient Journey evidence;
- post-merge artifact content is validated;
- Issues #34 and #58 are still open;
- no human-usability TODO is checked by Phase 12.

Only then may Issue #230 close as completed.

## 20. Scope boundary for later phases

Phase 12 deliberately ends at Patient journey engineering evidence.

Later phases remain responsible for:

- Phase 13 Partner Journey Lab;
- Phase 14 Doctor Journey Lab;
- Phase 15 Doctor Cognitive Load;
- Phase 16 Wrong-Patient Safety;
- Phase 20 Accessibility Lab breadth;
- Phase 21 AI Red-Team expansion;
- Phase 22 Clinical + Playful Collision;
- Phase 34 pre-human validation rollup;
- Phase 35 real Patient + Doctor human validation transition.

Phase 12 must not absorb these scopes in order to make its own evidence look more complete.
