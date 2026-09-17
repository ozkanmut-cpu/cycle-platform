# Phase 12 Patient Journey Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build deterministic, machine-readable Patient journey evidence by driving the real Flutter Patient UI through critical privacy, Today, Quick Log, timeline/calendar, and Connected Health flows without claiming human usability evidence.

**Architecture:** Keep all journey models, fixtures, drivers, detectors, canonical serialization, and evidence writing in `apps/patient/test/support/`. Exercise the real `PatientHomePage` and production widgets with `WidgetTester`; production code gains only a minimal injectable clock seam in `patient_home.dart` so Today/Quick Log output can be deterministic. Add a separate Flutter `patient-journey` job to Simulation Lab CI and upload exact artifact `simulation-patient-journey-evidence`.

**Tech Stack:** Flutter stable, Dart >=3.10, `flutter_test`, existing Patient app/domain/storage packages, GitHub Actions `subosito/flutter-action@v2`, canonical JSON via `dart:convert`, evidence file I/O via `dart:io` in test-only code.

**Spec:** `docs/superpowers/specs/2026-09-17-patient-journey-lab-design.md`

## Global Constraints

- Base branch is `main`; Phase 12 branch is `phase-12-patient-journey-lab`.
- Production field-maintenance host/path are forbidden: never touch `srv.field-maintenance-prod.com` or `/opt/field-maintenance/app`.
- Production Patient widgets/navigation/domain behavior remain authoritative; do not build a copied Patient simulator.
- Journey/evidence APIs remain test-only under `apps/patient/test/support/`.
- If a real Patient defect is found, add a focused production regression test before modifying production behavior.
- The only planned production seam is an injectable Patient clock if needed; default production behavior remains `DateTime.now`.
- `AuditEvent.now()` remains production-authoritative and wall-clock based. Canonical evidence must never serialize audit IDs or audit timestamps; record deterministic audit action/count/subject summaries only.
- Connected Health stale coverage is direct real-widget presentation coverage because the current builder does not emit stale; do not alter `ConnectedHealthViewModelBuilder` just to manufacture stale home-route coverage.
- Canonical Phase 12 fixtures derive from synthetic P-001, P-002, and P-005 only; no production PHI or human participant data.
- Canonical evidence contains `syntheticEvidenceOnly: true` and never claims human comprehension, ease, trust, or task completion.
- Issues #34 and #58 stay open. `TODO.md` human-usability item stays unchecked.
- Hard severity: privacy disclosure / sensitive content while locked / missing-as-zero / conflict collapsed to certainty = S4; blocked core journey / missing recovery / persistence-audit-retrieval mismatch = S3.
- Soft metrics such as action count, navigation count, and recovery count do not independently fail release gates.
- Same code + fixtures + seed + locale + fixed UTC virtual-now must produce byte-identical normalized JSON.
- Exact artifact name: `simulation-patient-journey-evidence`.
- Feature and merge SHAs both require full repository CI and Simulation Lab Patient Journey success before Phase 12 is complete.

---

## File Structure

Create focused test-only units:

- `apps/patient/test/support/patient_journey_models.dart` — journey enums/models/findings/coverage/report and canonical JSON.
- `apps/patient/test/support/patient_journey_fixtures.dart` — stable P-001/P-002/P-005 `HealthEvent` fixtures and fixed clock.
- `apps/patient/test/support/patient_journey_harness.dart` — in-memory repository/audit/session/app-lock doubles and localized production widget bootstrap.
- `apps/patient/test/support/patient_journey_driver.dart` — `WidgetTester` actions/observations against real controls only.
- `apps/patient/test/support/patient_journey_suite.dart` — canonical scenario execution, detector, coverage gate, report build.
- `apps/patient/test/patient_journey_models_test.dart` — model/serialization/malformed/detector/coverage unit tests.
- `apps/patient/test/patient_journey_harness_test.dart` — deterministic fixture and harness behavior.
- `apps/patient/test/patient_journey_privacy_today_test.dart` — privacy recovery/lifecycle and Today journeys.
- `apps/patient/test/patient_journey_logging_history_test.dart` — Quick Log persistence/audit/timeline/calendar journeys.
- `apps/patient/test/patient_journey_connected_health_test.dart` — observed/missing/conflicting/provenance home-route + stale direct-widget journey.
- `apps/patient/test/patient_journey_smoke_test.dart` — production-UI canonical suite and evidence writer.
- `apps/patient/lib/patient_home.dart` — minimal `now` injection only.
- `docs/SIMULATION_PATIENT_JOURNEY.md` — architecture/evidence/runbook/human-evidence boundary.
- `.github/workflows/simulation-lab.yml` — trigger expansion + separate Flutter `patient-journey` job + exact artifact upload.

No new package dependency is expected.

---

### Task 1: Add the minimal deterministic Patient clock seam

**Files:**
- Modify: `apps/patient/lib/patient_home.dart`
- Create: `apps/patient/test/patient_home_clock_test.dart`

**Interfaces:**
- Consumes: existing `PatientHomePage(session:, appLock:)`, `CycleTimeline`, Quick Log production flow.
- Produces: source-compatible `PatientHomePage(..., DateTime Function()? now)` behavior exposed internally as `widget.now()`; production default remains wall-clock.

- [ ] **Step 1: Write a failing regression test proving an injected instant drives cycle day and Quick Log event time**

Use a minimal existing-style in-memory `PatientVaultSession`/repository and a fixed `DateTime.utc(2026, 9, 17, 9)`.

```dart
final fixedNow = DateTime.utc(2026, 9, 17, 9);
await tester.pumpWidget(
  localizedPatientApp(
    PatientHomePage(
      session: session,
      appLock: AlwaysUnlockedAppLock(),
      now: () => fixedNow,
    ),
  ),
);
await tester.pumpAndSettle();
await tester.tap(find.text('Quick Log'));
await tester.pumpAndSettle();
await tester.tap(find.text('Headache'));
await tester.pumpAndSettle();

final created = repository.events.singleWhere(
  (event) => event.eventType == 'symptom.headache',
);
expect(created.id, 'event-${fixedNow.microsecondsSinceEpoch}');
expect(created.temporal.observedAt, fixedNow);
expect(created.temporal.recordedAt, fixedNow);
expect(created.temporal.knownAt, fixedNow);
```

The test should not inspect `AuditEvent.id` or `AuditEvent.occurredAt`.

- [ ] **Step 2: Run the focused test and verify RED**

From repo root in the approved Flutter container/worktree:

```bash
docker run --rm -v "$PWD":/repo -w /repo/apps/patient ghcr.io/cirruslabs/flutter:stable \
  sh -lc 'flutter pub get && flutter test test/patient_home_clock_test.dart'
```

Expected: compile failure because `PatientHomePage` has no `now` argument.

- [ ] **Step 3: Implement the minimal seam**

In `patient_home.dart`, use one default function and replace only journey-relevant direct wall-clock reads:

```dart
DateTime _patientSystemNow() => DateTime.now();

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({
    required this.session,
    required this.appLock,
    this.now = _patientSystemNow,
    super.key,
  });

  final PatientVaultSession session;
  final AppLockService appLock;
  final DateTime Function() now;
}
```

In `_logSelection`:

```dart
final now = widget.now().toUtc();
```

In `build`:

```dart
final cycleDay = timeline.cycleDayFor(widget.now());
```

Do not modify `AppLockService` or `AuditEvent.now()`.

- [ ] **Step 4: Run focused + existing Patient regressions**

```bash
docker run --rm -v "$PWD":/repo -w /repo/apps/patient ghcr.io/cirruslabs/flutter:stable \
  sh -lc 'flutter pub get && flutter test test/patient_home_clock_test.dart test/patient_usability_test.dart test/quick_log_test.dart test/cycle_timeline_test.dart test/month_calendar_test.dart test/patient_home_connected_health_test.dart'
```

Expected: PASS.

- [ ] **Step 5: Format and commit only Task 1 files**

```bash
dart format apps/patient/lib/patient_home.dart apps/patient/test/patient_home_clock_test.dart
git add apps/patient/lib/patient_home.dart apps/patient/test/patient_home_clock_test.dart
git commit -m "test(patient): add deterministic journey clock seam"
```

---

### Task 2: Build canonical Patient journey models, detector, and coverage gate

**Files:**
- Create: `apps/patient/test/support/patient_journey_models.dart`
- Create: `apps/patient/test/patient_journey_models_test.dart`

**Interfaces:**
- Produces:
  - `enum PatientJourneyFamily { privacyUnlockRecovery, privacyLifecycleRelock, todayComprehensionSurface, quickLogPersistence, timelineCalendarRetrieval, connectedHealthStates }`
  - `enum PatientJourneySeverity { none, s3, s4 }`
  - `PatientJourneyScenario`
  - `PatientJourneyObservation`
  - `PatientJourneyFinding`
  - `PatientJourneyResult`
  - `PatientJourneyCoverage`
  - `PatientJourneyReport`
  - `PatientJourneyDetector.evaluate(...)`
  - `PatientJourneyReportBuilder.build(...)`
  - `String canonicalPatientJourneyJson(PatientJourneyReport report)`

- [ ] **Step 1: Write RED tests for schema validation and canonical JSON**

```dart
test('scenario requires stable ids and UTC virtual time', () {
  expect(
    () => PatientJourneyScenario(
      id: '',
      schemaVersion: 1,
      seed: 20260917,
      virtualNow: DateTime.utc(2026, 9, 17),
      fixtureId: 'P-001',
      locale: 'en',
      family: PatientJourneyFamily.todayComprehensionSurface,
      actions: const ['open-home'],
      assertions: const ['today-visible'],
    ),
    throwsArgumentError,
  );
});

test('report JSON is byte stable independent of input result order', () {
  final a = reportBuilder.build(results: [resultB, resultA]);
  final b = reportBuilder.build(results: [resultA, resultB]);
  expect(canonicalPatientJourneyJson(a), canonicalPatientJourneyJson(b));
});
```

Also test duplicate action IDs, non-UTC time, unsupported schema, duplicate journey IDs, and JSON round-trip.

- [ ] **Step 2: Run models test and verify RED**

```bash
flutter test test/patient_journey_models_test.dart
```

Expected: missing model symbols.

- [ ] **Step 3: Implement stable model shapes**

Use explicit fields and stable ordering. `PatientJourneyObservation` must contain deterministic summaries only:

```dart
class PatientJourneyObservation {
  const PatientJourneyObservation({
    this.surfaceReached,
    this.satisfiedAssertions = const <String>[],
    this.repositoryEventDelta = 0,
    this.persistedEventType,
    this.auditActions = const <String>[],
    this.timelineRetrieved = false,
    this.calendarRetrieved = false,
    this.privacyCoverVisible = false,
    this.sensitiveMarkerVisible = false,
    this.connectedHealthStates = const <String>[],
    this.actionCount = 0,
    this.navigationCount = 0,
    this.recoveryCount = 0,
    this.executionFailureCode,
  });
  // fields + canonical toJson sorted at report level
}
```

Do not include framework exception strings, object identities, audit IDs/times, screenshots, or host paths.

- [ ] **Step 4: Implement detector categories exactly from the spec**

The detector may inspect normalized observations/assertion results, not copied production rules.

```dart
if (observation.privacyCoverVisible && observation.sensitiveMarkerVisible) {
  findings.add(const PatientJourneyFinding(
    category: 'sensitive_content_exposed_while_locked',
    severity: PatientJourneySeverity.s4,
    reasonCode: 'locked_sensitive_marker_visible',
    assertionId: 'privacy-no-sensitive-content',
  ));
}
```

Include categories:
`privacy_cover_bypass`, `sensitive_content_exposed_while_locked`, `missing_data_invented_as_zero`, `conflict_collapsed_to_certainty`, `core_journey_blocked`, `recovery_affordance_missing`, `persistence_mismatch`, `audit_mismatch`, `timeline_retrieval_failure`, `calendar_retrieval_failure`, `connected_health_state_mismatch`, `malformed_input`, `coverage_gap`.

- [ ] **Step 5: Implement mandatory coverage labels**

`PatientJourneyCoverage` must positively account for:

```text
family:privacyUnlockRecovery
family:privacyLifecycleRelock
family:todayComprehensionSurface
family:quickLogPersistence
family:timelineCalendarRetrieval
family:connectedHealthStates
privacy:unlock-success
privacy:auth-failure-recovery
privacy:lifecycle-relock
privacy:locked-negative-assertion
today:known-cycle-day
today:unknown-cycle-day
quick-log:persistence
quick-log:audit
quick-log:timeline-visible
history:timeline
history:calendar
connected-health:observed-home
connected-health:missing-home
connected-health:conflicting-home
connected-health:provenance-home
connected-health:stale-direct-widget
fixture:P-001
fixture:P-002
fixture:P-005
control:positive
control:negative
```

Missing any mandatory label yields deterministic failing `coverage_gap:<label>` evidence.

- [ ] **Step 6: Add detector self-tests and coverage-gap RED/GREEN checks**

Inject impossible observations only in unit tests and assert S3/S4 mapping. Example:

```dart
final result = detector.evaluate(
  scenario: privacyScenario,
  observation: const PatientJourneyObservation(
    privacyCoverVisible: true,
    sensitiveMarkerVisible: true,
  ),
);
expect(result.findings.single.severity, PatientJourneySeverity.s4);
```

- [ ] **Step 7: Run, format, commit**

```bash
flutter test test/patient_journey_models_test.dart
dart format test/support/patient_journey_models.dart test/patient_journey_models_test.dart
git add apps/patient/test/support/patient_journey_models.dart apps/patient/test/patient_journey_models_test.dart
git commit -m "test(patient): add journey evidence model"
```

---

### Task 3: Build deterministic Patient journey fixtures and harness

**Files:**
- Create: `apps/patient/test/support/patient_journey_fixtures.dart`
- Create: `apps/patient/test/support/patient_journey_harness.dart`
- Create: `apps/patient/test/patient_journey_harness_test.dart`

**Interfaces:**
- Produces:
  - `MutablePatientJourneyClock`
  - `JourneyHealthEventRepository implements HealthEventRepository`
  - `JourneyAuditLogRepository implements AuditLogRepository`
  - `JourneyPatientVaultSession extends PatientVaultSession`
  - `QueuedJourneyAppLock extends AppLockService`
  - `PatientJourneyHarness`
  - `Widget buildPatientJourneyApp(...)`
  - stable fixture builders `p001Events(...)`, `p002Events(...)`, `p005Events(...)`.

- [ ] **Step 1: Write RED tests for deterministic fixture boundaries**

```dart
test('queued app lock returns authentication outcomes in order', () async {
  final lock = QueuedJourneyAppLock([false, true]);
  expect(await lock.authenticate(), isFalse);
  expect(await lock.authenticate(), isTrue);
  expect(lock.authenticateCalls, 2);
});

test('journey repository preserves stable upsert/query order', () async {
  final repository = JourneyHealthEventRepository(p001Events(fixedNow));
  await repository.upsert(newEvent);
  final events = await repository.query(subjectId: 'local-owner');
  expect(events.map((e) => e.id), containsAllInOrder(expectedIds));
});
```

- [ ] **Step 2: Run and verify RED**

```bash
flutter test test/patient_journey_harness_test.dart
```

- [ ] **Step 3: Implement a mutable fixed clock**

```dart
class MutablePatientJourneyClock {
  MutablePatientJourneyClock(this.current);
  DateTime current;
  DateTime now() => current;
  void advance(Duration duration) => current = current.add(duration);
}
```

Canonical initial instant: `DateTime.utc(2026, 9, 17, 9)`.

- [ ] **Step 4: Implement repository and audit doubles using production interfaces**

Repository must filter by `subjectId`, preserve insertion order, and expose deterministic `events` for observation.

```dart
class JourneyAuditLogRepository implements AuditLogRepository {
  final events = <AuditEvent>[];

  @override
  Future<void> append(AuditEvent event) async => events.add(event);

  @override
  Future<List<AuditEvent>> listForSubject(String subjectId, {int limit = 200}) async =>
      events.where((e) => e.subjectId == subjectId).take(limit).toList();
}
```

Canonical evidence later consumes only `events.map((e) => e.action.name)` and stable subject type/count data, never audit IDs/timestamps.

- [ ] **Step 5: Implement session and app-lock doubles**

`JourneyPatientVaultSession` overrides `repository`, `auditLog`, `initialize`, `unlock`, `lock`, and `state`; record call counts but do not emulate SQLCipher internals.

`QueuedJourneyAppLock` consumes a finite ordered `List<bool>`; empty queue is an explicit harness error, not implicit success.

- [ ] **Step 6: Implement synthetic P-001/P-002/P-005 fixtures**

Use only stable synthetic IDs such as:

```text
P-001-period-start-20260905
P-001-cramps-20260905
P-002-spo2-health-connect
P-002-spo2-healthkit
P-005-sensitive-headache
```

All `HealthEvent.subjectId` values used by Patient home must be `local-owner`. Preserve source/provenance for connected-health events and use differing SpO2 values for conflict.

- [ ] **Step 7: Implement localized production widget bootstrap**

Reuse real `PatientLocalizations.supportedLocales` and Flutter localization delegates. `PatientJourneyHarness.pumpHome` must create real `PatientHomePage` with session, app lock, and injected clock.

- [ ] **Step 8: Run harness tests + existing connected-health home regression and commit**

```bash
flutter test test/patient_journey_harness_test.dart test/patient_home_connected_health_test.dart
dart format test/support/patient_journey_fixtures.dart test/support/patient_journey_harness.dart test/patient_journey_harness_test.dart
git add apps/patient/test/support/patient_journey_fixtures.dart apps/patient/test/support/patient_journey_harness.dart apps/patient/test/patient_journey_harness_test.dart
git commit -m "test(patient): add journey harness fixtures"
```

---

### Task 4: Implement privacy recovery, lifecycle relock, and Today journeys

**Files:**
- Create: `apps/patient/test/support/patient_journey_driver.dart`
- Create: `apps/patient/test/patient_journey_privacy_today_test.dart`
- Modify: `apps/patient/test/support/patient_journey_suite.dart` (create initially in this task)

**Interfaces:**
- Produces `PatientJourneyDriver` action methods and the first canonical scenario executors.
- Driver methods interact only through `WidgetTester` and real widgets/text/semantics.

- [ ] **Step 1: Write RED privacy unlock/recovery test**

Scenario auth queue: `[false, true]`. Assert after first failure:

```dart
expect(find.text('Authentication required'), findsOneWidget);
expect(find.text('Unlock'), findsOneWidget);
expect(find.text('P-005-sensitive-headache'), findsNothing);
```

Then tap the real Unlock button, pump, and verify the real home surface is reachable.

- [ ] **Step 2: Write RED lifecycle relock test**

Start unlocked with a fixture that yields a visible sensitive timeline label, then:

```dart
await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
await tester.pump();
expect(find.text('Private data locked'), findsOneWidget);
expect(find.text(sensitiveVisibleLabel), findsNothing);
```

Resume, follow production authentication, and assert home restoration only after auth.

- [ ] **Step 3: Write RED Today known/unknown journey tests**

Known fixture includes a deterministic period start. Unknown fixture contains no period start. Assertions use production copy/labels only:

```dart
expect(find.text('Today'), findsOneWidget);
expect(find.text('Quick Log'), findsOneWidget);
expect(find.text('Connected Health'), findsOneWidget);
```

For unknown cycle day assert the localized unknown state, not a numeric invented day.

- [ ] **Step 4: Run and verify the tests fail only because driver/suite code is absent**

```bash
flutter test test/patient_journey_privacy_today_test.dart
```

If a production behavior fails an expected contract, stop and use systematic-debugging; do not weaken the journey assertion.

- [ ] **Step 5: Implement driver methods**

Examples:

```dart
Future<void> tapText(String label) async {
  await tester.tap(find.text(label));
  actionCount += 1;
  await tester.pumpAndSettle();
}

Future<void> lifecycle(AppLifecycleState state) async {
  await tester.binding.handleAppLifecycleStateChanged(state);
  actionCount += 1;
  await tester.pump();
}
```

Track action/navigation/recovery counts explicitly in the driver; do not infer them from framework internals.

- [ ] **Step 6: Implement scenario execution normalization**

`patient_journey_suite.dart` converts observed UI facts into `PatientJourneyObservation`, then runs `PatientJourneyDetector`. It does not duplicate display/business rules.

- [ ] **Step 7: Run focused tests + usability regression and commit**

```bash
flutter test test/patient_journey_privacy_today_test.dart test/patient_usability_test.dart
dart format test/support/patient_journey_driver.dart test/support/patient_journey_suite.dart test/patient_journey_privacy_today_test.dart
git add apps/patient/test/support/patient_journey_driver.dart apps/patient/test/support/patient_journey_suite.dart apps/patient/test/patient_journey_privacy_today_test.dart
git commit -m "test(patient): cover privacy and today journeys"
```

---

### Task 5: Implement Quick Log persistence and timeline/calendar retrieval journeys

**Files:**
- Create: `apps/patient/test/patient_journey_logging_history_test.dart`
- Modify: `apps/patient/test/support/patient_journey_driver.dart`
- Modify: `apps/patient/test/support/patient_journey_suite.dart`

**Interfaces:**
- Consumes real Quick Log ActionChip selection and Patient home repository/audit/reload flow.
- Produces `quickLogPersistence` and `timelineCalendarRetrieval` canonical journey results.

- [ ] **Step 1: Write RED Quick Log end-to-end test**

Drive the real home:

```dart
await driver.tapText('Quick Log');
await driver.tapText('Headache');

final created = harness.repository.events.singleWhere(
  (event) => event.eventType == 'symptom.headache',
);
expect(created.id, 'event-${fixedNow.microsecondsSinceEpoch}');
expect(harness.audit.events.map((e) => e.action), contains(AuditAction.created));
expect(find.text('Headache'), findsOneWidget);
```

This test must not call repository `upsert` itself for the logged event.

- [ ] **Step 2: Write RED prior timeline/calendar retrieval test**

Preload P-001 history, verify a prior visible production timeline label, open the real Calendar affordance, and assert the deterministic prior date/event marker available through `MonthCalendar`.

Use `scrollUntilVisible` when needed instead of inspecting widget internals.

- [ ] **Step 3: Run and verify RED**

```bash
flutter test test/patient_journey_logging_history_test.dart
```

- [ ] **Step 4: Add only the driver helpers needed by the real controls**

Examples: open Quick Log, select localized event label, open calendar by tooltip/text, scroll to a marker. Each helper increments explicit soft metrics.

- [ ] **Step 5: Normalize deterministic persistence/audit/history observations**

Evidence may include:

```json
{
  "repositoryEventDelta": 1,
  "persistedEventType": "symptom.headache",
  "auditActions": ["created"],
  "timelineRetrieved": true,
  "calendarRetrieved": true
}
```

Do not include `AuditEvent.id`, `occurredAt`, or unordered metadata.

- [ ] **Step 6: Run regressions and commit**

```bash
flutter test test/patient_journey_logging_history_test.dart test/quick_log_test.dart test/cycle_timeline_test.dart test/month_calendar_test.dart
dart format test/support/patient_journey_driver.dart test/support/patient_journey_suite.dart test/patient_journey_logging_history_test.dart
git add apps/patient/test/support/patient_journey_driver.dart apps/patient/test/support/patient_journey_suite.dart apps/patient/test/patient_journey_logging_history_test.dart
git commit -m "test(patient): cover logging and history journeys"
```

---

### Task 6: Implement Connected Health home-route and stale presentation journeys

**Files:**
- Create: `apps/patient/test/patient_journey_connected_health_test.dart`
- Modify: `apps/patient/test/support/patient_journey_suite.dart`

**Interfaces:**
- Produces canonical `connectedHealthStates` observations with route metadata distinguishing `home-route` from `direct-production-widget`.

- [ ] **Step 1: Write RED observed/provenance home-route journey**

Preload one supported Health Connect event, open Connected Health from real `PatientHomePage`, and assert production metric label/value plus source label.

- [ ] **Step 2: Write RED missing home-route journey**

Start with no connected events, open real Connected Health route, assert `No connected health data yet.` and assert `find.text('0')` finds nothing.

- [ ] **Step 3: Write RED conflicting home-route journey**

Use P-002 conflicting Health Connect + HealthKit SpO2 fixtures. Assert `Sources conflict`, combined source label, and no fabricated numeric trailing value for the conflicting metric.

- [ ] **Step 4: Write RED stale direct-production-widget journey**

Pump the real production screen directly with:

```dart
const ConnectedHealthScreen(
  viewModel: ConnectedHealthViewModel(
    metrics: [
      ConnectedHealthMetricSummary(
        label: 'SpO2',
        state: ConnectedHealthMetricState.stale,
        sourceLabel: 'Health Connect',
      ),
    ],
  ),
)
```

Assert stale production copy is visible and numeric `0` is not displayed. Record coverage source as `direct-production-widget`, not `home-route`.

- [ ] **Step 5: Run and verify RED/GREEN by adding suite normalization only**

Do not change `ConnectedHealthViewModelBuilder` to emit stale.

```bash
flutter test test/patient_journey_connected_health_test.dart
```

- [ ] **Step 6: Run existing Connected Health regressions and commit**

```bash
flutter test test/patient_journey_connected_health_test.dart test/connected_health_screen_test.dart test/connected_health_view_model_builder_test.dart test/patient_home_connected_health_test.dart
dart format test/support/patient_journey_suite.dart test/patient_journey_connected_health_test.dart
git add apps/patient/test/support/patient_journey_suite.dart apps/patient/test/patient_journey_connected_health_test.dart
git commit -m "test(patient): cover connected health journeys"
```

---

### Task 7: Build canonical smoke evidence, documentation, and Simulation Lab Flutter job

**Files:**
- Create: `apps/patient/test/patient_journey_smoke_test.dart`
- Modify: `apps/patient/test/support/patient_journey_suite.dart`
- Create: `docs/SIMULATION_PATIENT_JOURNEY.md`
- Modify: `.github/workflows/simulation-lab.yml`

**Interfaces:**
- Produces `Future<PatientJourneyReport> runCanonicalPatientJourneySuite(WidgetTester tester, {int seed = 20260917})`.
- Writes `apps/patient/patient-journey-evidence.json` during canonical smoke.
- CI artifact exact name: `simulation-patient-journey-evidence`.

- [ ] **Step 1: Write RED same-seed smoke test**

The smoke test executes canonical scenarios and serializes one report. Add a separate unit/widget test path that builds canonical output twice and compares strings before file write.

```dart
final first = canonicalPatientJourneyJson(await runCanonicalPatientJourneySuite(tester));
final second = canonicalPatientJourneyJson(await runCanonicalPatientJourneySuite(tester));
expect(second, first);
```

If running the suite twice in one widget test causes shared binding state, use two isolated `testWidgets` cases and compare against a deterministic expected report hash/string produced by the same canonical builder without reusing mutable harness state.

- [ ] **Step 2: Implement final coverage gate and smoke writer**

```dart
final report = await runCanonicalPatientJourneySuite(tester, seed: 20260917);
expect(report.passed, isTrue, reason: report.failureSummary);
final json = canonicalPatientJourneyJson(report);
File('patient-journey-evidence.json').writeAsStringSync('$json\n');
```

The report must include `syntheticEvidenceOnly: true`, all mandatory coverage labels, sorted results, and no human-result wording.

- [ ] **Step 3: Run smoke twice from a clean Patient working directory and compare bytes**

```bash
cd apps/patient
rm -f patient-journey-evidence.json /tmp/patient-journey-1.json
flutter test test/patient_journey_smoke_test.dart
cp patient-journey-evidence.json /tmp/patient-journey-1.json
flutter test test/patient_journey_smoke_test.dart
cmp /tmp/patient-journey-1.json patient-journey-evidence.json
sha256sum patient-journey-evidence.json
```

Expected: `cmp` exits 0.

- [ ] **Step 4: Document the evidence contract**

Create `docs/SIMULATION_PATIENT_JOURNEY.md` covering:

- purpose and real-UI authority;
- six journey families;
- P-001/P-002/P-005 synthetic fixtures;
- clock seam and audit normalization boundary;
- stale direct-widget vs home-route distinction;
- S3/S4 findings and soft metrics;
- canonical smoke command;
- artifact name;
- #34/#58 human-evidence boundary;
- Phase 13/14/15/20/34/35 deferred scopes.

Canonical local command:

```bash
cd apps/patient
flutter pub get
flutter test test/patient_journey_smoke_test.dart
```

- [ ] **Step 5: Extend Simulation Lab path filters**

Add `apps/patient/**` and `docs/SIMULATION_PATIENT_JOURNEY.md` to pull-request and main-push path filters. Preserve all existing Phase 1-11 paths.

- [ ] **Step 6: Add separate Flutter `patient-journey` job**

Use repository CI toolchain convention:

```yaml
  patient-journey:
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Patient dependencies
        run: flutter pub get
        working-directory: apps/patient
      - name: Patient journey format check
        run: dart format --output=none --set-exit-if-changed lib test
        working-directory: apps/patient
      - name: Analyze Patient
        run: flutter analyze
        working-directory: apps/patient
      - name: Patient journey smoke
        run: flutter test test/patient_journey_smoke_test.dart
        working-directory: apps/patient
      - name: Patient journey regressions
        run: >-
          flutter test
          test/patient_usability_test.dart
          test/quick_log_test.dart
          test/cycle_timeline_test.dart
          test/month_calendar_test.dart
          test/connected_health_screen_test.dart
          test/connected_health_view_model_builder_test.dart
          test/patient_home_connected_health_test.dart
          test/patient_home_clock_test.dart
        working-directory: apps/patient
      - name: Upload Patient journey evidence
        uses: actions/upload-artifact@v4
        with:
          name: simulation-patient-journey-evidence
          path: apps/patient/patient-journey-evidence.json
          if-no-files-found: error
          retention-days: 7
```

- [ ] **Step 7: Run full Patient checks locally**

```bash
cd apps/patient
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test test/patient_journey_smoke_test.dart
```

Expected: no analyzer errors/warnings and all tests PASS. If analyzer emits only pre-existing infos, record exact count and verify no new warning/error.

- [ ] **Step 8: Remove generated evidence before source commit and commit Task 7**

The evidence JSON is CI output, not a source fixture.

```bash
rm -f apps/patient/patient-journey-evidence.json
git status --short
git add apps/patient/test/patient_journey_smoke_test.dart apps/patient/test/support/patient_journey_suite.dart docs/SIMULATION_PATIENT_JOURNEY.md .github/workflows/simulation-lab.yml
git commit -m "ci(simulation): add patient journey evidence"
```

---

### Task 8: Final verification, review, exact-SHA publication, merge, and Phase 12 closure

**Files:**
- No planned implementation files beyond Tasks 1-7.
- Update Issue #230 only after post-merge verification.
- Do not modify Issue #34/#58 bodies or close them.

**Interfaces:**
- Consumes final Phase 12 branch candidate.
- Produces verified merged Phase 12 on `main`, exact feature/merge CI evidence, exact artifact validation, and closed/completed #230 only.

- [ ] **Step 1: Run fresh verification on the final candidate**

From repo root using a clean approved worktree/container:

```bash
cd apps/patient
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
rm -f patient-journey-evidence.json /tmp/patient-journey-first.json
flutter test test/patient_journey_smoke_test.dart
cp patient-journey-evidence.json /tmp/patient-journey-first.json
flutter test test/patient_journey_smoke_test.dart
cmp /tmp/patient-journey-first.json patient-journey-evidence.json
sha256sum patient-journey-evidence.json
```

Also validate JSON programmatically or with a one-shot script:

```text
syntheticEvidenceOnly == true
configured == evaluated
evaluated == passed
failed == 0
malformed == 0
all six families > 0
all mandatory coverage labels > 0
fixtures P-001/P-002/P-005 > 0
```

Delete generated evidence afterward before tree comparison.

- [ ] **Step 2: Run focused repository hygiene checks**

Verify:

```bash
git status --short
git diff --check
grep -RInE 'TBD|FIXME' apps/patient/test/support apps/patient/test/patient_journey_* docs/SIMULATION_PATIENT_JOURNEY.md || true
grep -RIn '/opt/field-maintenance/app\|srv.field-maintenance-prod.com' apps/patient docs/SIMULATION_PATIENT_JOURNEY.md .github/workflows/simulation-lab.yml || true
```

Any unexpected generated lock/evidence/temp file must be removed before candidate publication.

- [ ] **Step 3: Perform final code review against the spec**

Review specifically for:

- copied production UI/business rules in the harness;
- direct repository insertion in the Quick Log journey;
- sensitive content visible while privacy cover is active;
- audit ID/timestamp leaking into canonical evidence;
- framework stack paths or nondeterministic exception text in evidence;
- stale state falsely represented as builder/home-route coverage;
- missing mandatory coverage labels;
- language implying human comprehension/ease;
- modifications to `TODO.md`, Issue #34, or Issue #58.

Resolve every Critical/Important finding before publication.

- [ ] **Step 4: Recheck human blockers immediately before PR**

Issue #34 must be `open`; Issue #58 must be `open` with `state_reason: reopened`. If either is closed, reopen before proceeding. All human-session acceptance criteria remain unchecked.

- [ ] **Step 5: Publish branch and verify exact remote tree**

Normal authenticated Git push is preferred. If unavailable and GitHub connector/Git Data is required, compare the final remote root tree SHA to the locally verified root tree SHA before opening a PR. Never treat a staging/publisher tree as the final candidate.

- [ ] **Step 6: Open Phase 12 PR and wait for exact feature-SHA checks**

PR title: `Phase 12: patient journey lab`.

Required exact feature-head gates:

```text
CI: completed/success
Simulation Lab foundation job: completed/success if triggered
Simulation Lab patient-journey job: completed/success
artifact simulation-patient-journey-evidence exists
artifact JSON matches local canonical evidence semantics and SHA-256
```

Queued/in-progress is never GREEN.

- [ ] **Step 7: Validate feature artifact independently**

Download exact `simulation-patient-journey-evidence` from the feature run. Unzip/parse and verify the same semantic invariants and JSON SHA-256 as the local canonical file.

- [ ] **Step 8: Guarded merge**

Immediately before merge recheck:

```text
PR head == verified feature SHA
PR base == current expected main SHA
PR mergeable == true/clean
#34 open
#58 open/reopened
no unresolved Critical/Important review threads
```

Use exact-head guarded squash merge so temporary publication history, if any, is not carried into main.

- [ ] **Step 9: Verify exact merge SHA**

After merge:

```text
main HEAD == returned merge SHA
merged tree contains the verified feature content
post-merge CI run is on exact merge SHA
post-merge Simulation Lab run is on exact merge SHA
```

Wait for `completed/success` on full repository CI and the Patient Journey Simulation Lab job.

- [ ] **Step 10: Validate post-merge artifact**

Download `simulation-patient-journey-evidence` from the exact merge-SHA run and verify semantic invariants plus SHA-256 against the verified feature artifact. Same code/tree must preserve canonical evidence.

- [ ] **Step 11: Close only Issue #230**

Update #230 acceptance checklist with concrete evidence (feature SHA/run/artifact, merge SHA/run/artifact) and close with `state_reason: completed` only after all gates above pass.

Re-fetch #34 and #58 afterward and verify both remain open (#58 open/reopened). Do not check the human-usability item in `TODO.md`.

- [ ] **Step 12: Report completion without starting Phase 13**

Final status must state:

```text
Phase 12 complete
PR/merge SHA
feature CI + patient-journey run IDs
post-merge CI + patient-journey run IDs
artifact IDs + canonical JSON SHA-256
#230 closed/completed
#34 open
#58 open/reopened
Phase 13 not started
```

---

## Execution Notes

- Use `superpowers:using-git-worktrees` at execution start to establish an isolated worktree under `/tmp/cycle-*` from the exact Phase 12 branch head.
- Use `superpowers:test-driven-development` for every implementation task.
- On any unexpected test/build behavior, use `superpowers:systematic-debugging` before proposing a fix.
- Before claiming any task/phase complete, use `superpowers:verification-before-completion`.
- Before merge, use `superpowers:requesting-code-review`; if subagents are unavailable, perform the explicit focused review checklist in Task 8.
- Use `superpowers:finishing-a-development-branch` for PR/merge integration.
- Do not begin Phase 13 in the same execution cycle that closes Phase 12.
