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
- The only production seam is an injectable Patient clock on `PatientHomePage`; default production behavior remains `DateTime.now`.
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
- Produces: source-compatible `PatientHomePage(session:, appLock:, DateTime Function() now = _patientSystemNow)` behavior exposed internally as `widget.now()`; production default remains wall-clock.

- [ ] **Step 1: Write a failing regression test proving an injected instant drives cycle day and Quick Log event time**

Create `patient_home_clock_test.dart` with these exact test-local helpers so Task 1 has no dependency on later harness work:

```dart
class _ClockAppLock extends AppLockService {
  @override
  bool get authInProgress => false;

  @override
  Future<bool> authenticate({
    LockSensitivity sensitivity = LockSensitivity.standard,
  }) async => true;

  @override
  Future<void> cancel() async {}
}

class _ClockRepository implements HealthEventRepository {
  _ClockRepository(this.events);
  final List<HealthEvent> events;

  @override
  Future<void> upsert(HealthEvent event) async => events.add(event);

  @override
  Future<HealthEvent?> getById(String id) async {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Future<List<HealthEvent>> query({
    required String subjectId,
    String? eventType,
    DateTime? from,
    DateTime? to,
    bool includeSuperseded = false,
  }) async => events.where((event) => event.subjectId == subjectId).toList();

  @override
  Future<void> markDeleted({
    required String eventId,
    required DateTime deletedAt,
  }) async {}
}

class _ClockAuditLog implements AuditLogRepository {
  final List<AuditEvent> events = <AuditEvent>[];

  @override
  Future<void> append(AuditEvent event) async => events.add(event);

  @override
  Future<List<AuditEvent>> listForSubject(
    String subjectId, {
    int limit = 200,
  }) async => events
      .where((event) => event.subjectId == subjectId)
      .take(limit)
      .toList();
}

class _ClockSession extends PatientVaultSession {
  _ClockSession(this.clockRepository, this.clockAuditLog);
  final _ClockRepository clockRepository;
  final _ClockAuditLog clockAuditLog;

  @override
  HealthEventRepository get repository => clockRepository;
  @override
  AuditLogRepository get auditLog => clockAuditLog;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> unlock() async {}
  @override
  Future<void> lock() async {}
  @override
  Future<VaultState> state() async => VaultState.unlocked;
}

Widget _clockTestApp(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: PatientLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    PatientLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

HealthEvent _periodStart(DateTime observedAt) => HealthEvent(
  id: 'clock-period-start',
  subjectId: 'local-owner',
  eventType: 'menstruation.period_start',
  temporal: TemporalMetadata(
    observedAt: observedAt,
    recordedAt: observedAt,
    knownAt: observedAt,
  ),
  provenance: const Provenance(sourceKind: SourceKind.patient),
  verificationStatus: VerificationStatus.selfReported,
  confidence: ConfidenceClass.high,
  privacyClass: 'reproductive',
  schemaVersion: 1,
);

testWidgets('injected clock drives cycle day and Quick Log timestamp', (
  tester,
) async {
  final fixedNow = DateTime.utc(2026, 9, 17, 9);
  final repository = _ClockRepository(<HealthEvent>[
    _periodStart(DateTime.utc(2026, 9, 5, 9)),
  ]);
  final session = _ClockSession(repository, _ClockAuditLog());

  await tester.pumpWidget(
    _clockTestApp(
      PatientHomePage(
        session: session,
        appLock: _ClockAppLock(),
        now: () => fixedNow,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Cycle day 13'), findsOneWidget);

  await tester.tap(find.byTooltip('Calendar'));
  await tester.pumpAndSettle();
  expect(find.text('2026-09'), findsOneWidget);
  await tester.tapAt(const Offset(4, 4));
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
});
```

Required imports are `cycle_core_domain`, `cycle_patient/app_lock.dart`, `cycle_patient/patient_home.dart`, `cycle_patient/patient_localizations.dart`, `cycle_patient/vault_session.dart`, `cycle_security`, `cycle_storage`, Flutter Material/localizations, and `flutter_test`. Do not add a dependency.

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

In `_openCalendar`, pass the same clock through the production widget's existing seam:

```dart
child: MonthCalendar(events: _events, initialMonth: widget.now()),
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
  - `PatientJourneyScenario({required String id, required int schemaVersion, required int seed, required DateTime virtualNow, required String fixtureId, required String locale, required PatientJourneyFamily family, required List<String> actions, required List<String> assertions, List<String> expectedRecoveryAffordances = const [], List<String> riskTags = const []})`
  - `PatientJourneyObservation({String? surfaceReached, List<String> satisfiedAssertions = const [], int repositoryEventDelta = 0, String? persistedEventType, List<String> auditActions = const [], bool timelineExpected = false, bool timelineRetrieved = false, bool calendarExpected = false, bool calendarRetrieved = false, bool privacyCoverVisible = false, bool privacyCoverBypassed = false, bool sensitiveMarkerVisible = false, bool missingDisplayedAsZero = false, bool conflictDisplayedAsCertain = false, bool coreJourneyBlocked = false, bool? recoveryAffordanceVisible, bool? persistenceMatched, bool? auditMatched, bool? connectedHealthStateMatched, List<String> connectedHealthStates = const [], String? connectedHealthCoverageSource, int actionCount = 0, int navigationCount = 0, int recoveryCount = 0, String? malformedReasonCode, String? executionFailureCode})`
  - `PatientJourneyFinding({required String category, required PatientJourneySeverity severity, required String journeyId, required String assertionId, required String reasonCode, Map<String, Object?> diagnostics = const {}})`
  - `PatientJourneyResult({required PatientJourneyScenario scenario, required PatientJourneyObservation observation, required List<PatientJourneyFinding> findings, required Set<String> coverageLabels})`, with `bool get passed => findings.isEmpty`.
  - `PatientJourneyCoverage({required int configured, required int evaluated, required int passed, required int failed, required int malformed, required Map<String, int> labels})`, with exact static `Set<String> mandatoryLabels` from Step 5.
  - `PatientJourneyReport({required int schemaVersion, required int seed, required DateTime virtualNow, required bool syntheticEvidenceOnly, required List<PatientJourneyResult> results, required List<PatientJourneyFinding> findings, required PatientJourneyCoverage coverage, required int actionCount, required int navigationCount, required int recoveryCount})`, with `bool get passed` and deterministic `String get failureSummary`.
  - `PatientJourneyReport.fromJson(Map<String, Object?> json)` for the round-trip validation test.
  - `PatientJourneyDetector.evaluate({required PatientJourneyScenario scenario, required PatientJourneyObservation observation, required Set<String> coverageLabels})`
  - `PatientJourneyReportBuilder({required int seed, required DateTime virtualNow}).build({required Iterable<PatientJourneyResult> results})`
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
  PatientJourneyResult result(String id) {
    final scenario = PatientJourneyScenario(
      id: id,
      schemaVersion: 1,
      seed: 20260917,
      virtualNow: DateTime.utc(2026, 9, 17, 9),
      fixtureId: 'P-001',
      locale: 'en',
      family: PatientJourneyFamily.todayComprehensionSurface,
      actions: const <String>['open-home'],
      assertions: const <String>['today-visible'],
    );
    return PatientJourneyResult(
      scenario: scenario,
      observation: const PatientJourneyObservation(
        surfaceReached: 'today',
        satisfiedAssertions: <String>['today-visible'],
        actionCount: 1,
      ),
      findings: const <PatientJourneyFinding>[],
      coverageLabels: const <String>{
        'family:todayComprehensionSurface',
        'fixture:P-001',
        'control:positive',
      },
    );
  }

  final builder = PatientJourneyReportBuilder(
    seed: 20260917,
    virtualNow: DateTime.utc(2026, 9, 17, 9),
  );
  final resultA = result('journey-a');
  final resultB = result('journey-b');
  final a = builder.build(results: <PatientJourneyResult>[resultB, resultA]);
  final b = builder.build(results: <PatientJourneyResult>[resultA, resultB]);
  expect(canonicalPatientJourneyJson(a), canonicalPatientJourneyJson(b));
});
```

Add explicit tests named `rejects duplicate action ids`, `rejects non-UTC virtual time`, `rejects unsupported schema version`, and `rejects duplicate journey ids`. Add the round-trip test with fully defined input:

```dart
test('canonical report JSON round-trips', () {
  final report = PatientJourneyReport(
    schemaVersion: 1,
    seed: 20260917,
    virtualNow: DateTime.utc(2026, 9, 17, 9),
    syntheticEvidenceOnly: true,
    results: const <PatientJourneyResult>[],
    findings: const <PatientJourneyFinding>[],
    coverage: const PatientJourneyCoverage(
      configured: 0,
      evaluated: 0,
      passed: 0,
      failed: 0,
      malformed: 0,
      labels: <String, int>{},
    ),
    actionCount: 0,
    navigationCount: 0,
    recoveryCount: 0,
  );
  final first = canonicalPatientJourneyJson(report);
  final decoded = Map<String, Object?>.from(jsonDecode(first) as Map);
  final restored = PatientJourneyReport.fromJson(decoded);
  expect(canonicalPatientJourneyJson(restored), first);
});
```

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
    this.timelineExpected = false,
    this.timelineRetrieved = false,
    this.calendarExpected = false,
    this.calendarRetrieved = false,
    this.privacyCoverVisible = false,
    this.privacyCoverBypassed = false,
    this.sensitiveMarkerVisible = false,
    this.missingDisplayedAsZero = false,
    this.conflictDisplayedAsCertain = false,
    this.coreJourneyBlocked = false,
    this.recoveryAffordanceVisible,
    this.persistenceMatched,
    this.auditMatched,
    this.connectedHealthStateMatched,
    this.connectedHealthStates = const <String>[],
    this.connectedHealthCoverageSource,
    this.actionCount = 0,
    this.navigationCount = 0,
    this.recoveryCount = 0,
    this.malformedReasonCode,
    this.executionFailureCode,
  });
}
```

Implement every constructor field from the Interfaces block as a final field. Validate schema version `1`, nonblank IDs, UTC `virtualNow`, unique/nonblank actions and assertions, and nonnegative counters. `PatientJourneyReportBuilder.build` sorts results by `scenario.id`, sorts each result's coverage labels/findings, accumulates label counts into a `SplayTreeMap<String, int>`, and appends one report-level deterministic finding with `category: 'coverage_gap'`, `severity: s3`, `journeyId: 'coverage'`, `assertionId: label`, and `reasonCode: 'coverage_gap:$label'` per absent mandatory label. `canonicalPatientJourneyJson` uses `jsonEncode(report.toJson())` where every emitted map is insertion-ordered and every emitted list is pre-sorted. Do not include framework exception strings, object identities, audit IDs/times, screenshots, or host paths.

- [ ] **Step 4: Implement detector categories exactly from the spec**

The detector inspects normalized observations/assertion results, not copied production rules.

```dart
if (observation.privacyCoverVisible && observation.sensitiveMarkerVisible) {
  findings.add(PatientJourneyFinding(
    category: 'sensitive_content_exposed_while_locked',
    severity: PatientJourneySeverity.s4,
    journeyId: scenario.id,
    reasonCode: 'locked_sensitive_marker_visible',
    assertionId: 'privacy-no-sensitive-content',
  ));
}
```

Map the remaining normalized fields exactly: `privacyCoverBypassed` -> `privacy_cover_bypass` S4; `missingDisplayedAsZero` -> `missing_data_invented_as_zero` S4; `conflictDisplayedAsCertain` -> `conflict_collapsed_to_certainty` S4; `coreJourneyBlocked` or non-null `executionFailureCode` -> `core_journey_blocked` S3; `recoveryAffordanceVisible == false` -> `recovery_affordance_missing` S3; `persistenceMatched == false` -> `persistence_mismatch` S3; `auditMatched == false` -> `audit_mismatch` S3; `timelineExpected && !timelineRetrieved` -> `timeline_retrieval_failure` S3; `calendarExpected && !calendarRetrieved` -> `calendar_retrieval_failure` S3; `connectedHealthStateMatched == false` -> `connected_health_state_mismatch` S3; non-null `malformedReasonCode` -> `malformed_input` S3. Include categories:
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

Inject impossible observations only in unit tests and assert S3/S4 mapping with this exact setup:

```dart
final scenario = PatientJourneyScenario(
  id: 'privacy-negative-control',
  schemaVersion: 1,
  seed: 20260917,
  virtualNow: DateTime.utc(2026, 9, 17, 9),
  fixtureId: 'P-005',
  locale: 'en',
  family: PatientJourneyFamily.privacyLifecycleRelock,
  actions: const <String>['pause-app'],
  assertions: const <String>['privacy-no-sensitive-content'],
);
final result = PatientJourneyDetector().evaluate(
  scenario: scenario,
  observation: const PatientJourneyObservation(
    privacyCoverVisible: true,
    sensitiveMarkerVisible: true,
  ),
  coverageLabels: const <String>{'control:negative'},
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

Expected GREEN: the model test exits `0`; invalid constructors throw `ArgumentError`, detector malformed-input self-tests normalize those failures to stable `malformed_input` reason codes without serializing exception text, every defined category maps to S3/S4 exactly, canonical JSON round-trips byte-identically, input result order does not affect bytes, and each absent mandatory label yields one sorted report-level `coverage_gap:<label>` finding.

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
  - `PatientJourneyHarness({required DateTime virtualNow, required Iterable<HealthEvent> events, required Iterable<bool> authenticationOutcomes})`
  - `Widget buildPatientJourneyApp({required Widget home, Locale locale = const Locale('en')})`
  - `Future<void> clearPatientJourneyWidgetTree(WidgetTester tester)`
  - `HealthEvent patientJourneyEvent({required String id, required String eventType, required DateTime observedAt, num? value, String? unit, int? severity, SourceKind sourceKind = SourceKind.patient, String privacyClass = 'reproductive'})`
  - stable fixture builders `List<HealthEvent> p001Events(DateTime virtualNow)`, `List<HealthEvent> p002Events(DateTime virtualNow)`, and `List<HealthEvent> p005Events(DateTime virtualNow)`.

- [ ] **Step 1: Write RED tests for deterministic fixture boundaries**

```dart
test('queued app lock returns authentication outcomes in order', () async {
  final lock = QueuedJourneyAppLock([false, true]);
  expect(await lock.authenticate(), isFalse);
  expect(await lock.authenticate(), isTrue);
  expect(lock.authenticateCalls, 2);
});

test('journey repository preserves stable upsert/query order', () async {
  final fixedNow = DateTime.utc(2026, 9, 17, 9);
  final repository = JourneyHealthEventRepository(p001Events(fixedNow));
  final newEvent = patientJourneyEvent(
    id: 'P-001-headache-20260917',
    eventType: 'symptom.headache',
    observedAt: fixedNow,
  );
  final expectedIds = <String>[
    ...p001Events(fixedNow).map((event) => event.id),
    newEvent.id,
  ];
  await repository.upsert(newEvent);
  final events = await repository.query(subjectId: 'local-owner');
  expect(events.map((e) => e.id), containsAllInOrder(expectedIds));
});
```

- [ ] **Step 2: Run and verify RED**

```bash
flutter test test/patient_journey_harness_test.dart
```

Expected RED: compile failures for `QueuedJourneyAppLock`, `JourneyHealthEventRepository`, `patientJourneyEvent`, and fixture builders because none exist before Task 3.

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
class JourneyHealthEventRepository implements HealthEventRepository {
  JourneyHealthEventRepository(Iterable<HealthEvent> seed)
      : events = List<HealthEvent>.of(seed);

  final List<HealthEvent> events;
  final Set<String> _deletedIds = <String>{};

  @override
  Future<void> upsert(HealthEvent event) async {
    final index = events.indexWhere((existing) => existing.id == event.id);
    if (index == -1) {
      events.add(event);
    } else {
      events[index] = event;
    }
  }

  @override
  Future<HealthEvent?> getById(String id) async {
    if (_deletedIds.contains(id)) return null;
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Future<List<HealthEvent>> query({
    required String subjectId,
    String? eventType,
    DateTime? from,
    DateTime? to,
    bool includeSuperseded = false,
  }) async => events.where((event) {
    if (_deletedIds.contains(event.id)) return false;
    if (event.subjectId != subjectId) return false;
    if (eventType != null && event.eventType != eventType) return false;
    if (from != null && event.temporal.observedAt.isBefore(from)) return false;
    if (to != null && event.temporal.observedAt.isAfter(to)) return false;
    final supersededIds = events
        .map((candidate) => candidate.supersedesEventId)
        .whereType<String>()
        .toSet();
    if (!includeSuperseded && supersededIds.contains(event.id)) return false;
    return true;
  }).toList();

  @override
  Future<void> markDeleted({
    required String eventId,
    required DateTime deletedAt,
  }) async => _deletedIds.add(eventId);
}

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

`JourneyPatientVaultSession` overrides `repository`, `auditLog`, `initialize`, `unlock`, `lock`, and `state`; record call counts but do not emulate SQLCipher internals. `QueuedJourneyAppLock` consumes a finite ordered `List<bool>`; empty queue is an explicit harness error, not implicit success:

```dart
class JourneyPatientVaultSession extends PatientVaultSession {
  JourneyPatientVaultSession(this.journeyRepository, this.journeyAuditLog);

  final JourneyHealthEventRepository journeyRepository;
  final JourneyAuditLogRepository journeyAuditLog;
  VaultState _state = VaultState.uninitialized;
  int initializeCalls = 0;
  int unlockCalls = 0;
  int lockCalls = 0;

  @override
  HealthEventRepository get repository => journeyRepository;
  @override
  AuditLogRepository get auditLog => journeyAuditLog;
  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    _state = VaultState.unlocked;
  }
  @override
  Future<void> unlock() async {
    unlockCalls += 1;
    _state = VaultState.unlocked;
  }
  @override
  Future<void> lock() async {
    lockCalls += 1;
    _state = VaultState.locked;
  }
  @override
  Future<VaultState> state() async => _state;
}

class QueuedJourneyAppLock extends AppLockService {
  QueuedJourneyAppLock(Iterable<bool> outcomes)
      : _outcomes = ListQueue<bool>.of(outcomes);

  final ListQueue<bool> _outcomes;
  int authenticateCalls = 0;
  int cancelCalls = 0;

  @override
  bool get authInProgress => false;

  @override
  Future<bool> authenticate({
    LockSensitivity sensitivity = LockSensitivity.standard,
  }) async {
    authenticateCalls += 1;
    if (_outcomes.isEmpty) {
      throw StateError('No queued authentication outcome.');
    }
    return _outcomes.removeFirst();
  }

  @override
  Future<void> cancel() async => cancelCalls += 1;
}
```

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

Implement `patientJourneyEvent` once and build the fixture lists only through it. Exact canonical contents are:

```dart
void _requireUtc(DateTime value) {
  if (!value.isUtc) throw ArgumentError.value(value, 'virtualNow', 'must be UTC');
}

HealthEvent patientJourneyEvent({
  required String id,
  required String eventType,
  required DateTime observedAt,
  num? value,
  String? unit,
  int? severity,
  SourceKind sourceKind = SourceKind.patient,
  String privacyClass = 'reproductive',
}) => HealthEvent(
  id: id,
  subjectId: 'local-owner',
  eventType: eventType,
  value: value,
  unit: unit,
  severity: severity,
  dataState: DataState.yes,
  temporal: TemporalMetadata(
    observedAt: observedAt,
    recordedAt: observedAt,
    knownAt: observedAt,
  ),
  provenance: Provenance(sourceKind: sourceKind, sourceRecordId: id),
  verificationStatus: sourceKind == SourceKind.patient
      ? VerificationStatus.selfReported
      : VerificationStatus.deviceMeasured,
  confidence: ConfidenceClass.high,
  privacyClass: privacyClass,
  schemaVersion: 1,
);

List<HealthEvent> p001Events(DateTime virtualNow) {
  _requireUtc(virtualNow);
  return <HealthEvent>[
  patientJourneyEvent(
    id: 'P-001-period-start-20260905',
    eventType: 'menstruation.period_start',
    observedAt: DateTime.utc(2026, 9, 5, 9),
  ),
  patientJourneyEvent(
    id: 'P-001-cramps-20260905',
    eventType: 'symptom.cramps',
    observedAt: DateTime.utc(2026, 9, 5, 10),
    severity: 2,
  ),
  ];
}

List<HealthEvent> p002Events(DateTime virtualNow) {
  _requireUtc(virtualNow);
  return <HealthEvent>[
  patientJourneyEvent(
    id: 'P-002-spo2-health-connect',
    eventType: 'vital.oxygen_saturation',
    observedAt: DateTime.utc(2026, 9, 17, 8),
    value: 98,
    unit: '%',
    sourceKind: SourceKind.healthConnect,
    privacyClass: 'health',
  ),
  patientJourneyEvent(
    id: 'P-002-spo2-healthkit',
    eventType: 'vital.oxygen_saturation',
    observedAt: DateTime.utc(2026, 9, 17, 8, 1),
    value: 91,
    unit: '%',
    sourceKind: SourceKind.healthKit,
    privacyClass: 'health',
  ),
  ];
}

List<HealthEvent> p005Events(DateTime virtualNow) {
  _requireUtc(virtualNow);
  return <HealthEvent>[
  patientJourneyEvent(
    id: 'P-005-sensitive-headache',
    eventType: 'symptom.headache',
    observedAt: DateTime.utc(2026, 9, 17, 7),
  ),
  ];
}
```

The fixed fixture timestamps above do not derive from wall clock; `virtualNow` is validated as UTC to keep every fixture entry point deterministic.

- [ ] **Step 7: Implement localized production widget bootstrap**

Reuse real `PatientLocalizations.supportedLocales` and Flutter localization delegates. `PatientJourneyHarness.pumpHome` must create real `PatientHomePage` with session, app lock, and injected clock.

```dart
Widget buildPatientJourneyApp({
  required Widget home,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: PatientLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    PatientLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

Future<void> clearPatientJourneyWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

class PatientJourneyHarness {
  PatientJourneyHarness({
    required DateTime virtualNow,
    required Iterable<HealthEvent> events,
    required Iterable<bool> authenticationOutcomes,
  }) {
    _requireUtc(virtualNow);
    clock = MutablePatientJourneyClock(virtualNow);
    repository = JourneyHealthEventRepository(events);
    audit = JourneyAuditLogRepository();
    session = JourneyPatientVaultSession(repository, audit);
    appLock = QueuedJourneyAppLock(authenticationOutcomes);
  }

  late final MutablePatientJourneyClock clock;
  late final JourneyHealthEventRepository repository;
  late final JourneyAuditLogRepository audit;
  late final JourneyPatientVaultSession session;
  late final QueuedJourneyAppLock appLock;

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(buildPatientJourneyApp(
      home: PatientHomePage(
        session: session,
        appLock: appLock,
        now: clock.now,
      ),
    ));
    await tester.pumpAndSettle();
  }
}
```

`PatientJourneyHarness` owns `clock`, `repository`, `audit`, `session`, and `appLock`; its constructor builds fresh instances from `virtualNow`, the fixture list, and authentication outcomes so no mutable state is shared between journeys.

- [ ] **Step 8: Run harness tests + existing connected-health home regression and commit**

```bash
flutter test test/patient_journey_harness_test.dart test/patient_home_connected_health_test.dart
dart format test/support/patient_journey_fixtures.dart test/support/patient_journey_harness.dart test/patient_journey_harness_test.dart
git add apps/patient/test/support/patient_journey_fixtures.dart apps/patient/test/support/patient_journey_harness.dart apps/patient/test/patient_journey_harness_test.dart
git commit -m "test(patient): add journey harness fixtures"
```

Expected GREEN: both test files exit `0`; the harness test proves ordered authentication, UTC fixture rejection, stable repository ordering, session state transitions, audit append/list behavior, localized bootstrap, and cleanup between two fresh harnesses.

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
final virtualNow = DateTime.utc(2026, 9, 17, 9);
final harness = PatientJourneyHarness(
  virtualNow: virtualNow,
  events: p005Events(virtualNow),
  authenticationOutcomes: const <bool>[false, true],
);
await harness.pumpHome(tester);
expect(find.text('Authentication required'), findsOneWidget);
expect(find.text('Unlock'), findsOneWidget);
expect(find.text('Headache').hitTestable(), findsNothing);

await tester.tap(find.text('Unlock'));
await tester.pumpAndSettle();
expect(find.text('Today'), findsOneWidget);
expect(find.text('Headache'), findsOneWidget);
expect(harness.appLock.authenticateCalls, 2);
```

The negative assertion uses the user-visible production label (`Headache`), not the fixture ID, because IDs are never rendered. Add a semantics assertion that the locked semantics tree contains neither `Headache` nor the fixture ID; if that assertion exposes a production privacy defect, add the failing focused regression before changing `PatientHomePage`.

- [ ] **Step 2: Write RED lifecycle relock test**

Start unlocked with a fixture that yields a visible sensitive timeline label, then:

```dart
final virtualNow = DateTime.utc(2026, 9, 17, 9);
final harness = PatientJourneyHarness(
  virtualNow: virtualNow,
  events: p005Events(virtualNow),
  authenticationOutcomes: const <bool>[true, true],
);
await harness.pumpHome(tester);
expect(find.text('Headache'), findsOneWidget);

await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
await tester.pump();
expect(find.text('Private data locked'), findsOneWidget);
expect(find.text('Headache').hitTestable(), findsNothing);

await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
await tester.pumpAndSettle();
expect(harness.appLock.authenticateCalls, 2);
expect(find.text('Today'), findsOneWidget);
expect(find.text('Headache'), findsOneWidget);
```

Resume, follow production authentication, and assert home restoration only after auth.

- [ ] **Step 3: Write RED Today known/unknown journey tests**

Known fixture includes a deterministic period start. Unknown fixture contains no period start. Assertions use production copy/labels only:

```dart
final virtualNow = DateTime.utc(2026, 9, 17, 9);
final known = PatientJourneyHarness(
  virtualNow: virtualNow,
  events: p001Events(virtualNow),
  authenticationOutcomes: const <bool>[true],
);
await known.pumpHome(tester);
expect(find.text('Today'), findsOneWidget);
expect(find.text('Quick Log'), findsOneWidget);
expect(find.text('Connected Health'), findsOneWidget);
expect(find.text('Cycle day 13'), findsOneWidget);

await tester.pumpWidget(const SizedBox.shrink());
await tester.pumpAndSettle();

final unknown = PatientJourneyHarness(
  virtualNow: virtualNow,
  events: p002Events(virtualNow),
  authenticationOutcomes: const <bool>[true],
);
await unknown.pumpHome(tester);
expect(find.text('Cycle day unknown'), findsOneWidget);
expect(find.textContaining('Cycle day 0'), findsNothing);
```

For unknown cycle day assert the localized unknown state, not a numeric invented day.

- [ ] **Step 4: Run and verify the tests fail only because driver/suite code is absent**

```bash
flutter test test/patient_journey_privacy_today_test.dart
```

Expected RED: compile failures for `PatientJourneyDriver` and the three suite executors. A failure in an already-existing production behavior is not the intended RED; stop and use systematic-debugging without weakening the assertion.

- [ ] **Step 5: Implement driver methods**

Implement these exact methods:

```dart
class PatientJourneyDriver {
  PatientJourneyDriver(this.tester);

  final WidgetTester tester;
  int actionCount = 0;
  int navigationCount = 0;
  int recoveryCount = 0;

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

  void recordNavigation() => navigationCount += 1;
  void recordRecovery() => recoveryCount += 1;
}
```

Track action/navigation/recovery counts explicitly in the driver; do not infer them from framework internals.

- [ ] **Step 6: Implement scenario execution normalization**

`patient_journey_suite.dart` converts observed UI facts into `PatientJourneyObservation`, then runs `PatientJourneyDetector`. It does not duplicate display/business rules.

Create these exact executors in this task:

```dart
Future<PatientJourneyResult> runPrivacyUnlockRecoveryJourney(
  WidgetTester tester,
);
Future<PatientJourneyResult> runPrivacyLifecycleRelockJourney(
  WidgetTester tester,
);
Future<List<PatientJourneyResult>> runTodayComprehensionJourneys(
  WidgetTester tester,
);
```

Each executor constructs its own `PatientJourneyHarness`, declares its complete `PatientJourneyScenario`, performs the real UI actions above, captures only normalized observation fields, and calls `PatientJourneyDetector.evaluate`. The Today executor returns exactly two results: `today-known-cycle-day` using P-001 and `today-unknown-cycle-day` using P-002 (which has no period start); it emits `today:known-cycle-day` and `today:unknown-cycle-day` respectively.

- [ ] **Step 7: Run focused tests + usability regression and commit**

```bash
flutter test test/patient_journey_privacy_today_test.dart test/patient_usability_test.dart
dart format test/support/patient_journey_driver.dart test/support/patient_journey_suite.dart test/patient_journey_privacy_today_test.dart
git add apps/patient/test/support/patient_journey_driver.dart apps/patient/test/support/patient_journey_suite.dart apps/patient/test/patient_journey_privacy_today_test.dart
git commit -m "test(patient): cover privacy and today journeys"
```

Expected GREEN: both test files exit `0`; privacy recovery, relock containment, known cycle day, and unknown cycle day results contain no S3/S4 findings and emit the exact Task 7 label mapping.

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
final fixedNow = DateTime.utc(2026, 9, 17, 9);
final harness = PatientJourneyHarness(
  virtualNow: fixedNow,
  events: p001Events(fixedNow),
  authenticationOutcomes: const <bool>[true],
);
await harness.pumpHome(tester);
final driver = PatientJourneyDriver(tester);
final beforeCount = harness.repository.events.length;
await driver.tapText('Quick Log');
await driver.tapText('Headache');

final created = harness.repository.events.singleWhere(
  (event) => event.eventType == 'symptom.headache',
);
expect(harness.repository.events.length - beforeCount, 1);
expect(created.id, 'event-${fixedNow.microsecondsSinceEpoch}');
expect(harness.audit.events.map((e) => e.action), contains(AuditAction.created));
expect(find.text('Headache'), findsOneWidget);
```

This test must not call repository `upsert` itself for the logged event.

The same test then calls `runQuickLogPersistenceJourney(tester)` after `clearPatientJourneyWidgetTree(tester)` and asserts its scenario ID is `quick-log-persistence`, `passed` is true, and its coverage labels contain `quick-log:persistence`, `quick-log:audit`, and `quick-log:timeline-visible`.

- [ ] **Step 2: Write RED prior timeline/calendar retrieval test**

Preload P-001 history, verify a prior visible production timeline label, open the real Calendar affordance, and assert the deterministic prior date/event marker available through `MonthCalendar`:

```dart
final fixedNow = DateTime.utc(2026, 9, 17, 9);
final harness = PatientJourneyHarness(
  virtualNow: fixedNow,
  events: p001Events(fixedNow),
  authenticationOutcomes: const <bool>[true],
);
await harness.pumpHome(tester);
final driver = PatientJourneyDriver(tester);

expect(find.text('Period started'), findsOneWidget);
await driver.tapTooltip('Calendar');
expect(find.text('2026-09'), findsOneWidget);
await tester.tap(find.bySemanticsLabel('2026-9-5, 2 events'));
await tester.pumpAndSettle();
expect(find.text('05.09.2026'), findsOneWidget);
expect(find.text('2 logged event(s)'), findsOneWidget);
```

Use `scrollUntilVisible` only through a named `PatientJourneyDriver.scrollUntilVisible(Finder finder)` helper; do not inspect widget state or repository internals to claim calendar retrieval.

The same test then calls `runTimelineCalendarRetrievalJourney(tester)` after cleanup and asserts scenario ID `timeline-calendar-retrieval`, `passed == true`, and both `history:timeline` and `history:calendar` labels.

- [ ] **Step 3: Run and verify RED**

```bash
flutter test test/patient_journey_logging_history_test.dart
```

Expected RED: compile failures for the two suite executors and the Task 5 driver methods that do not exist yet. No direct production assertion may be weakened to obtain RED/GREEN.

- [ ] **Step 4: Add only the driver helpers needed by the real controls**

Add exactly `tapTooltip(String)` and `scrollUntilVisible(Finder, {double delta = 300})` to the Task 4 `PatientJourneyDriver`; both increment `actionCount` and settle after interaction. Executors call `recordNavigation()` immediately after a route/sheet opens and `recordRecovery()` immediately after the successful Unlock retry. No counter is inferred from framework internals.

```dart
Future<void> tapTooltip(String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  actionCount += 1;
  await tester.pumpAndSettle();
}

Future<void> scrollUntilVisible(
  Finder finder, {
  double delta = 300,
}) async {
  await tester.scrollUntilVisible(finder, delta);
  actionCount += 1;
  await tester.pumpAndSettle();
}
```

- [ ] **Step 5: Normalize deterministic persistence/audit/history observations**

Evidence includes exactly these deterministic fields for this journey:

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

Add exact suite executors `Future<PatientJourneyResult> runQuickLogPersistenceJourney(WidgetTester tester)` and `Future<PatientJourneyResult> runTimelineCalendarRetrievalJourney(WidgetTester tester)`. The Quick Log result sets `persistenceMatched` from the one-event delta/type/timestamp comparison and `auditMatched` from exactly one `AuditAction.created` for subject type `health_event`; the history result sets both `timelineExpected` and `calendarExpected` true and records retrieval only from the visible production assertions above.

Expected GREEN: `flutter test test/patient_journey_logging_history_test.dart` exits `0`, both results have no findings, and the direct UI/repository/audit assertions remain unchanged.

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

```dart
final virtualNow = DateTime.utc(2026, 9, 17, 9);
final harness = PatientJourneyHarness(
  virtualNow: virtualNow,
  events: <HealthEvent>[
    patientJourneyEvent(
      id: 'P-002-observed-spo2-health-connect',
      eventType: 'vital.oxygen_saturation',
      observedAt: DateTime.utc(2026, 9, 17, 8),
      value: 98,
      unit: '%',
      sourceKind: SourceKind.healthConnect,
      privacyClass: 'health',
    ),
  ],
  authenticationOutcomes: const <bool>[true],
);
await harness.pumpHome(tester);
await PatientJourneyDriver(tester).tapText('Connected Health');
expect(find.text('SpO2'), findsOneWidget);
expect(find.text('98.0 %'), findsOneWidget);
expect(find.textContaining('Health Connect'), findsWidgets);
```

- [ ] **Step 2: Write RED missing home-route journey**

Start with no connected events, open real Connected Health route, assert `No connected health data yet.` and assert `find.text('0')` finds nothing.

```dart
final virtualNow = DateTime.utc(2026, 9, 17, 9);
final harness = PatientJourneyHarness(
  virtualNow: virtualNow,
  events: const <HealthEvent>[],
  authenticationOutcomes: const <bool>[true],
);
await harness.pumpHome(tester);
await PatientJourneyDriver(tester).tapText('Connected Health');
expect(find.text('No connected health data yet.'), findsOneWidget);
expect(find.text('0'), findsNothing);
```

- [ ] **Step 3: Write RED conflicting home-route journey**

Use P-002 conflicting Health Connect + HealthKit SpO2 fixtures. Assert `Sources conflict`, combined source label, and no fabricated numeric trailing value for the conflicting metric.

```dart
final virtualNow = DateTime.utc(2026, 9, 17, 9);
final harness = PatientJourneyHarness(
  virtualNow: virtualNow,
  events: p002Events(virtualNow),
  authenticationOutcomes: const <bool>[true],
);
await harness.pumpHome(tester);
await PatientJourneyDriver(tester).tapText('Connected Health');
await tester.scrollUntilVisible(find.text('SpO2'), 300);
expect(find.text('Sources conflict'), findsWidgets);
expect(find.textContaining('Health Connect + HealthKit'), findsOneWidget);
expect(find.text('94.5 %'), findsNothing);
expect(find.text('0'), findsNothing);
```

- [ ] **Step 4: Write RED stale direct-production-widget journey**

Pump the real production screen directly with:

```dart
await tester.pumpWidget(
  buildPatientJourneyApp(
    home: const ConnectedHealthScreen(
      viewModel: ConnectedHealthViewModel(
        metrics: <ConnectedHealthMetricSummary>[
          ConnectedHealthMetricSummary(
            label: 'SpO2',
            state: ConnectedHealthMetricState.stale,
            sourceLabel: 'Health Connect',
          ),
        ],
      ),
    ),
  ),
);
await tester.pumpAndSettle();
expect(find.text('Data stale'), findsWidgets);
expect(find.textContaining('Health Connect'), findsOneWidget);
expect(find.text('0'), findsNothing);
```

Record coverage source as `direct-production-widget`, not `home-route`. `Data stale` is the exact English string from `PatientLocalizations.staleHealthData`; do not duplicate builder logic.

Add a fifth widget test that calls the not-yet-implemented suite executor so the task has a genuine RED boundary:

```dart
final results = await runConnectedHealthJourneys(tester);
expect(
  results.map((result) => result.scenario.id),
  <String>[
    'connected-health-observed-provenance-home',
    'connected-health-missing-home',
    'connected-health-conflicting-home',
    'connected-health-stale-direct-widget',
  ],
);
expect(results.expand((result) => result.findings), isEmpty);
```

- [ ] **Step 5: Run and verify RED/GREEN by adding suite normalization only**

Do not change `ConnectedHealthViewModelBuilder` to emit stale.

Add one exact executor returning all state results:

```dart
Future<List<PatientJourneyResult>> runConnectedHealthJourneys(
  WidgetTester tester,
);
```

It returns exactly four result records: `connected-health-observed-provenance-home`, `connected-health-missing-home`, `connected-health-conflicting-home`, and `connected-health-stale-direct-widget`. The first record emits both `connected-health:observed-home` and `connected-health:provenance-home`; the stale record sets `connectedHealthCoverageSource: 'direct-production-widget'`; the other three set `home-route`. Each record uses a fresh harness/widget tree and is separated from the next by `clearPatientJourneyWidgetTree(tester)` from Task 3.

Expected RED before this implementation: compile failure because `runConnectedHealthJourneys` is undefined. Expected GREEN afterward: all five tests in `patient_journey_connected_health_test.dart` pass with no production builder change.

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

The smoke test uses one `testWidgets` case, invokes the entire suite twice with fresh state, compares canonical bytes, and writes only the already-compared second report:

The suite assigns coverage labels exactly as follows; labels within a row are a `Set<String>` and the builder counts them across results:

| Scenario ID | Required coverage labels |
|---|---|
| `privacy-unlock-recovery` | `family:privacyUnlockRecovery`, `privacy:unlock-success`, `privacy:auth-failure-recovery`, `privacy:locked-negative-assertion`, `fixture:P-005`, `control:positive`, `control:negative` |
| `privacy-lifecycle-relock` | `family:privacyLifecycleRelock`, `privacy:lifecycle-relock`, `privacy:locked-negative-assertion`, `fixture:P-005`, `control:positive`, `control:negative` |
| `today-known-cycle-day` | `family:todayComprehensionSurface`, `today:known-cycle-day`, `fixture:P-001`, `control:positive` |
| `today-unknown-cycle-day` | `family:todayComprehensionSurface`, `today:unknown-cycle-day`, `fixture:P-002`, `control:negative` |
| `quick-log-persistence` | `family:quickLogPersistence`, `quick-log:persistence`, `quick-log:audit`, `quick-log:timeline-visible`, `fixture:P-001`, `control:positive` |
| `timeline-calendar-retrieval` | `family:timelineCalendarRetrieval`, `history:timeline`, `history:calendar`, `fixture:P-001`, `control:positive` |
| `connected-health-observed-provenance-home` | `family:connectedHealthStates`, `connected-health:observed-home`, `connected-health:provenance-home`, `fixture:P-002`, `control:positive` |
| `connected-health-missing-home` | `family:connectedHealthStates`, `connected-health:missing-home`, `fixture:P-002`, `control:negative` |
| `connected-health-conflicting-home` | `family:connectedHealthStates`, `connected-health:conflicting-home`, `fixture:P-002`, `control:negative` |
| `connected-health-stale-direct-widget` | `family:connectedHealthStates`, `connected-health:stale-direct-widget`, `fixture:P-002`, `control:negative` |

```dart
testWidgets('canonical Patient journey evidence is byte stable', (tester) async {
  final firstReport = await runCanonicalPatientJourneySuite(
    tester,
    seed: 20260917,
  );
  final firstJson = canonicalPatientJourneyJson(firstReport);

  await clearPatientJourneyWidgetTree(tester);

  final secondReport = await runCanonicalPatientJourneySuite(
    tester,
    seed: 20260917,
  );
  final secondJson = canonicalPatientJourneyJson(secondReport);

  expect(secondJson, firstJson);
  expect(secondReport.passed, isTrue, reason: secondReport.failureSummary);
  final missingLabels = PatientJourneyCoverage.mandatoryLabels
      .where((label) => (secondReport.coverage.labels[label] ?? 0) <= 0)
      .toList();
  expect(missingLabels, isEmpty);
  expect(secondReport.syntheticEvidenceOnly, isTrue);
  expect(secondReport.coverage.failed, 0);
  expect(secondReport.coverage.malformed, 0);
  File('patient-journey-evidence.json').writeAsStringSync('$secondJson\n');

  await clearPatientJourneyWidgetTree(tester);
});
```

`runCanonicalPatientJourneySuite` must instantiate fresh scenario lists, harnesses, repositories, audit sinks, app-lock queues, and report builders on every call. It calls the Task 4, Task 5, and Task 6 executors in fixed family order, invokes `clearPatientJourneyWidgetTree(tester)` between every executor, then sorts results through `PatientJourneyReportBuilder`. No top-level mutable singleton or cached result is permitted.

- [ ] **Step 2: Implement final coverage gate and smoke writer**

```dart
bool get passed =>
    findings.isEmpty &&
    coverage.failed == 0 &&
    coverage.malformed == 0 &&
    coverage.configured == coverage.evaluated &&
    coverage.evaluated == coverage.passed;
```

Implement the `PatientJourneyReport.passed` getter above and derive `failureSummary` from sorted finding reason codes. Expose `PatientJourneyCoverage.mandatoryLabels` as the exact immutable set from Task 2. The report must include `syntheticEvidenceOnly: true`, all mandatory coverage labels, sorted results, and no human-result wording.

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

Add `apps/patient/**`, `docs/SIMULATION_PATIENT_JOURNEY.md`, `docs/superpowers/specs/2026-09-17-patient-journey-lab-design.md`, `docs/superpowers/plans/2026-09-17-patient-journey-lab.md`, and `.github/workflows/simulation-lab.yml` to pull-request and main-push path filters. Preserve all existing Phase 1-11 paths.

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

Expected: every command exits `0`; `flutter analyze` reports no issues and all tests PASS.

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

**Expected RED / gate failure:** any dirty candidate tree, local verification failure, unresolved Critical/Important review finding, absent artifact, semantic/hash mismatch, queued/in-progress/failed exact-SHA check, changed PR head, non-clean mergeability, closed #34/#58, checked human-usability TODO, or missing post-merge verification stops Task 8 immediately.

**Integration action:** publish only the verified feature SHA, open the Phase 12 PR, validate exact feature-SHA CI/artifact, perform the guarded squash merge, then validate exact merge-SHA CI/artifact before closing #230.

**Expected GREEN:** every Step 1–10 command/gate is successful on the exact stated SHA, #230 closes completed, #34 remains open, #58 remains open/reopened, the human-usability TODO remains unchecked, and Phase 13 is not started.

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

Validate JSON with this exact command:

```bash
jq -e '
  . as $report |
  [
    "family:privacyUnlockRecovery", "family:privacyLifecycleRelock",
    "family:todayComprehensionSurface", "family:quickLogPersistence",
    "family:timelineCalendarRetrieval", "family:connectedHealthStates",
    "privacy:unlock-success", "privacy:auth-failure-recovery",
    "privacy:lifecycle-relock", "privacy:locked-negative-assertion",
    "today:known-cycle-day", "today:unknown-cycle-day",
    "quick-log:persistence", "quick-log:audit", "quick-log:timeline-visible",
    "history:timeline", "history:calendar",
    "connected-health:observed-home", "connected-health:missing-home",
    "connected-health:conflicting-home", "connected-health:provenance-home",
    "connected-health:stale-direct-widget",
    "fixture:P-001", "fixture:P-002", "fixture:P-005",
    "control:positive", "control:negative"
  ] as $required |
  $report.syntheticEvidenceOnly == true and
  $report.coverage.configured == $report.coverage.evaluated and
  $report.coverage.evaluated == $report.coverage.passed and
  $report.coverage.failed == 0 and
  $report.coverage.malformed == 0 and
  all($required[]; ($report.coverage.labels[.] // 0) > 0)
' patient-journey-evidence.json
```

Expected: exit status `0` and output `true`.

Delete generated evidence afterward before tree comparison.

- [ ] **Step 2: Run focused repository hygiene checks**

Verify:

```bash
git status --short
git diff --check
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

Push the verified branch with authenticated Git using `git push origin HEAD:phase-12-patient-journey-lab`. Fetch the remote branch afterward and require its root tree SHA to equal the locally verified root tree SHA before opening a PR.

- [ ] **Step 6: Open Phase 12 PR and wait for exact feature-SHA checks**

PR title: `Phase 12: patient journey lab`.

Required exact feature-head gates:

```text
CI: completed/success
Simulation Lab foundation job: completed/success
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

## Plan Self-Review Record

- Spec coverage: every section of `docs/superpowers/specs/2026-09-17-patient-journey-lab-design.md` maps to Tasks 1–8; all six families, all 27 mandatory coverage labels, P-001/P-002/P-005, S3/S4 mapping, malformed input, canonical JSON, stale direct-widget scope, CI artifact, and the human-evidence boundary are explicit.
- Name/type consistency: every helper and fixture referenced by a test is defined in an earlier step or in the same code block; model constructor fields and suite return types are consistent across Tasks 2–7.
- Determinism: Task 7 contains one method only—two fresh suite invocations inside the same `testWidgets`, explicit neutral-tree cleanup between invocations, and byte equality before evidence write.
- Production boundary: Task 1 is the only planned production-code change; it injects one clock and passes it to Quick Log, cycle-day calculation, and the existing `MonthCalendar.initialMonth` seam. `AuditEvent.now()` and Connected Health builder behavior remain unchanged.
- Human boundary: #34 and #58 remain open, `syntheticEvidenceOnly: true` is mandatory, and the human-usability TODO remains unchecked.

---

## Execution Notes

- Use `superpowers:using-git-worktrees` at execution start to establish an isolated worktree under `/tmp/cycle-*` from the exact Phase 12 branch head.
- Use `superpowers:test-driven-development` for every implementation task.
- On any unexpected test/build behavior, use `superpowers:systematic-debugging` before proposing a fix.
- Before claiming any task/phase complete, use `superpowers:verification-before-completion`.
- Before merge, use `superpowers:requesting-code-review` and perform the explicit focused review checklist in Task 8.
- Use `superpowers:finishing-a-development-branch` for PR/merge integration.
- Do not begin Phase 13 in the same execution cycle that closes Phase 12.
