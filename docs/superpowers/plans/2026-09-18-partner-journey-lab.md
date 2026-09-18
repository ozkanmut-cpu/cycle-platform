# Phase 13 Partner Journey Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build deterministic synthetic Partner journeys against the real Flutter Partner UI and production sharing engines, with canonical CI evidence.

**Architecture:** Add one app-internal session controller that delegates pairing, notification privacy, and revocation to existing production services. Keep journey models, fixtures, harness, detector, coverage, and JSON entirely under `apps/partner/test/support/`; run them through a separate Flutter Simulation Lab job.

**Tech Stack:** Flutter stable, Dart >=3.6, `flutter_test`, `cycle_permissions`, `cycle_sharing`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-18-partner-journey-lab-design.md`

## Global Constraints

- Work only on `phase-13-partner-journey-lab` in `/tmp/cycle-*`.
- Production defaults use `DateTime.now`; canonical tests use `2026-09-18T09:00:00Z` and seed `20260918`.
- Pairing authenticates actor scope and never creates or widens a permission grant.
- Production sharing/relationship engines remain authoritative.
- Journey/evidence APIs stay under `apps/partner/test/support/`.
- Evidence contains `"syntheticEvidenceOnly": true` and excludes host paths, wall clock, stack traces, random IDs, object identities, and screenshot metadata.
- Issue #232 stays open until post-merge completion. Issues #34 and #58 stay open/reopened. The human-usability TODO stays unchecked.
- Queued or in-progress workflows are never green. Exact feature and merge SHAs require `completed/success`.

---

### Task 1: Production Partner session controller

**Files:**
- Create: `apps/partner/lib/partner_session.dart`
- Create: `apps/partner/test/partner_session_test.dart`

**Interfaces:**
- Produces `abstract interface class PairingPayloadSource { Future<String?> acquire(); }`.
- Produces `typedef PartnerNow = DateTime Function();` and `typedef KeyEnvelopeIdFactory = String Function();`.
- Produces immutable `PartnerSessionState` with `paired`, `invitation`, `privacyMode`, `deviceUnlocked`, `preview`, `errorCode`, and `notificationsStopped`.
- Produces `PartnerSessionController extends ChangeNotifier` with `pair()`, `setPrivacyMode()`, `setDeviceUnlocked()`, `previewNotification()`, and `disconnect()`.
- Produces `RegistryRecipientKeyRotator implements RecipientKeyRotator` backed by `RecipientKeyRegistry`.

Use this exact constructor contract:

```dart
PartnerSessionController({
  required String ownerId,
  required String recipientId,
  required PairingPayloadSource payloadSource,
  required PermissionGrant? revocationGrant,
  required RecipientKeyRotator keyRotator,
  Iterable<RelationshipCategoryGrant> notificationGrants = const [],
  RelationshipNotificationRequest? notificationRequest,
  PairingQrCodec pairingCodec = const PairingQrCodec(),
  RelationshipNotificationPipeline notificationPipeline =
      const RelationshipNotificationPipeline(),
  SharingRevocationCoordinator revocationCoordinator =
      const SharingRevocationCoordinator(),
  PartnerNow now = DateTime.now,
});
```

- [ ] **Step 1: Write controller RED tests**

Create tests that construct a queue payload source, fixed clock, real `PairingQrCodec`, real `RelationshipNotificationPipeline`, real `SharingRevocationCoordinator`, a real `PermissionGrant`, and registry-backed rotator. Assert:

```dart
await controller.pair();
expect(controller.state.paired, isTrue);
expect(controller.state.invitation!.ownerId, 'owner-RP-001');

await expiredController.pair();
expect(expiredController.state.paired, isFalse);
expect(expiredController.state.errorCode, 'pairing_expired');

await wrongScopeController.pair();
expect(wrongScopeController.state.errorCode, 'pairing_scope_mismatch');
```

Also assert malformed, unsupported-version, unavailable, and failed-then-success retry outcomes use stable codes and never expose exception text.

- [ ] **Step 2: Run RED**

Run: `flutter test test/partner_session_test.dart`

Expected: compile failure because `partner_session.dart` and its types do not exist.

- [ ] **Step 3: Implement minimal pairing state machine**

Implement `PairingPayloadSource`, `UnavailablePairingPayloadSource`, `PartnerSessionState`, and controller construction. `pair()` must acquire, decode at `now().toUtc()`, match `ownerId` and `recipientId`, and map failures to exactly:

```dart
const pairingUnavailable = 'pairing_unavailable';
const pairingMalformed = 'pairing_malformed';
const pairingExpired = 'pairing_expired';
const pairingUnsupportedVersion = 'pairing_unsupported_version';
const pairingScopeMismatch = 'pairing_scope_mismatch';
```

Classify `FormatException` by its stable production message inside the controller, but expose only the constants above. Successful pairing clears `errorCode` and sets the validated invitation.

- [ ] **Step 4: Add notification and revocation RED tests**

Use production requests/grants and assert:

```dart
controller.setPrivacyMode(NotificationPrivacyMode.detailedWhenUnlocked);
controller.setDeviceUnlocked(false);
controller.previewNotification();
expect(controller.state.preview!.redacted, isTrue);

await controller.disconnect();
expect(controller.state.paired, isFalse);
expect(controller.state.preview, isNull);
expect(controller.state.notificationsStopped, isTrue);
expect(registry.all().map((state) => state.version), containsAll(<int>[1, 2]));
```

- [ ] **Step 5: Implement production delegation**

`previewNotification()` calls only `RelationshipNotificationPipeline.present`. `disconnect()` calls only `SharingRevocationCoordinator.revoke`, then clears session/preview. `RegistryRecipientKeyRotator.rotate` invokes `RecipientKeyRegistry.rotate` with the injected `KeyEnvelopeIdFactory` and returns the new envelope ID.

- [ ] **Step 6: Run GREEN and regression**

Run:

```bash
flutter test test/partner_session_test.dart
flutter test
flutter analyze
```

Expected: all pass with no analyzer warnings.

- [ ] **Step 7: Commit**

```bash
git add apps/partner/lib/partner_session.dart apps/partner/test/partner_session_test.dart
git commit -m "feat(partner): add production-backed session controller"
```

### Task 2: Bind the real Partner UI to session state

**Files:**
- Modify: `apps/partner/lib/main.dart`
- Create: `apps/partner/lib/notification_privacy_preview.dart`
- Modify: `apps/partner/test/widget_test.dart`

**Interfaces:**
- Consumes `PartnerSessionController` from Task 1.
- Produces optional `sessionController` injection on `CyclePartnerApp` and `PartnerHomePage`.
- Produces `NotificationPrivacyPreview({required PrivateNotification notification})`.

- [ ] **Step 1: Write UI RED tests**

Add a `pairedController(...)` test helper with real production dependencies. Assert an unpaired controller hides `health.energy: steady`, valid pairing shows it, malformed pairing keeps it hidden, and disconnect removes it. Assert the page disposes only an internally created controller by pumping/replacing trees without exceptions.

Add notification preview assertions:

```dart
await tester.tap(find.text('Preview notification'));
await tester.pumpAndSettle();
expect(find.text('You have a private partner update.'), findsOneWidget);
expect(find.text(sensitiveDetail), findsNothing);
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/widget_test.dart`

Expected: failures because content is not paired-gated and preview UI does not exist.

- [ ] **Step 3: Implement UI binding**

Pass the controller through `CyclePartnerApp`. In `PartnerHomePage`, create the unavailable production controller only when injection is absent, subscribe/unsubscribe in `initState`, `didUpdateWidget`, and `dispose`, and render cards only when `state.paired` is true.

Change the pairing button to `await controller.pair()`. Display stable recovery copy for each error code and retain `Scan pairing QR` as retry. Bind the privacy dropdown to `setPrivacyMode`, add `Preview notification`, render `NotificationPrivacyPreview` only for non-null production output, and bind Disconnect to `await controller.disconnect()`.

The preview widget renders exactly `notification.title`, `notification.body`, and a `Redacted`/`Detailed` semantic label.

- [ ] **Step 4: Run GREEN and regression**

Run:

```bash
dart format lib test
flutter test test/widget_test.dart test/partner_session_test.dart
flutter test
flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add apps/partner/lib apps/partner/test/widget_test.dart
git commit -m "feat(partner): bind UI to pairing and privacy state"
```

### Task 3: Journey models, detector, canonical JSON, and coverage gate

**Files:**
- Create: `apps/partner/test/support/partner_journey_models.dart`
- Create: `apps/partner/test/partner_journey_models_test.dart`

**Interfaces:**
- Produces enums `PartnerJourneyFamily` and `PartnerJourneySeverity` with the exact spec values.
- Produces immutable `PartnerJourneyScenario`, `PartnerJourneyObservation`, `PartnerJourneyFinding`, `PartnerJourneyResult`, `PartnerJourneyCoverage`, and `PartnerJourneyReport`.
- Produces `PartnerJourneyDetector.evaluate(...)`, `PartnerJourneyReportBuilder.build(...)`, `mandatoryPartnerJourneyCoverageLabels`, and `canonicalPartnerJourneyJson(...)`.

- [ ] **Step 1: Write model/detector RED tests**

Construct complete objects inline; do not use undefined fixtures. Assert enum names, validation of blank/duplicate IDs and non-UTC time, JSON round-trip, stable sorting, all S4/S3 mappings, and one finding per missing mandatory label:

```dart
final report = PartnerJourneyReportBuilder(
  seed: 20260918,
  virtualNow: DateTime.utc(2026, 9, 18, 9),
).build(results);
expect(report.syntheticEvidenceOnly, isTrue);
expect(canonicalPartnerJourneyJson(report), canonicalPartnerJourneyJson(report));
expect(report.coverage.missingLabels, isEmpty);
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/partner_journey_models_test.dart`

Expected: compile failure because the model file does not exist.

- [ ] **Step 3: Implement exact models and validation**

Use schema version `1`, UTC ISO-8601 values, `SplayTreeMap` or explicitly sorted map insertion, and recursively sorted lists by stable ID. Reject malformed scenarios with `ArgumentError`; the suite catches them into `malformed_input` results.

Define the 40 mandatory labels verbatim from spec section 13. The report builder emits `coverage_gap:<label>` for each absent label and makes `passed` false for malformed, S3, S4, determinism mismatch, or coverage gap.

- [ ] **Step 4: Run GREEN**

Run:

```bash
dart format test/support/partner_journey_models.dart test/partner_journey_models_test.dart
flutter test test/partner_journey_models_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add apps/partner/test/support/partner_journey_models.dart apps/partner/test/partner_journey_models_test.dart
git commit -m "test(partner): add journey evidence model"
```

### Task 4: Deterministic fixtures and widget harness

**Files:**
- Create: `apps/partner/test/support/partner_journey_fixtures.dart`
- Create: `apps/partner/test/support/partner_journey_harness.dart`
- Create: `apps/partner/test/partner_journey_harness_test.dart`

**Interfaces:**
- Produces `rp001Fixture()`, `rp002Fixture()`, and `rp005Fixture()` returning `PartnerJourneyFixture` with real production inputs.
- Produces `QueuedPairingPayloadSource`, `RecordingNotificationSink`, `DeterministicEnvelopeFactory`, and `PartnerJourneyHarness`.
- Harness exposes `pump()`, `pair()`, `tapTab(String)`, `previewNotification()`, `disconnect()`, `observe(...)`, and `cleanup()`.

Define the fixture contract exactly:

```dart
class PartnerJourneyFixture {
  const PartnerJourneyFixture({
    required this.id,
    required this.ownerId,
    required this.recipientId,
    required this.virtualNow,
    required this.experienceInput,
    required this.revocationGrant,
    required this.notificationRequest,
    required this.notificationGrants,
    required this.invitationPayloads,
    required this.keyRegistry,
    required this.sensitiveMarkers,
  });
  // Fields use the production types named by the constructor.
}
```

- [ ] **Step 1: Write fixture/harness RED tests**

Assert all IDs, UTC times, actor scopes, grant states, invitation payloads, and sensitive markers are stable. Pump RP-001, pair through the real button, visit all tabs, and assert actions/navigation/recovery counts. Pump RP-002 locked and assert its detail marker is absent. Pump RP-005 and assert disconnect changes registry version 1 to 2.

- [ ] **Step 2: Run RED**

Run: `flutter test test/partner_journey_harness_test.dart`

Expected: compile failure because fixture and harness files do not exist.

- [ ] **Step 3: Implement fixtures**

Use exactly seed `20260918`, time `2026-09-18T09:00:00Z`, locale `en`, fixture IDs `RP-001`, `RP-002`, `RP-005`, and actor IDs derived from the fixture ID. Build real `PartnerExperienceInput`, grants, notification requests, invitations, permission grants, and registry states. Do not calculate expected visibility or redaction.

- [ ] **Step 4: Implement harness and cleanup**

Harness interactions use visible labels only. `cleanup()` executes:

```dart
await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
await tester.pumpAndSettle();
controller.dispose();
```

Each harness owns every mutable dependency and exposes normalized observation fields only.

- [ ] **Step 5: Run GREEN and regression**

Run:

```bash
dart format test/support test/partner_journey_harness_test.dart
flutter test test/partner_journey_harness_test.dart
flutter test test/widget_test.dart test/partner_session_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add apps/partner/test/support apps/partner/test/partner_journey_harness_test.dart
git commit -m "test(partner): add deterministic journey harness"
```

### Task 5: Pairing, navigation, and permission journeys

**Files:**
- Create: `apps/partner/test/partner_pairing_journey_test.dart`
- Create: `apps/partner/test/partner_visibility_journey_test.dart`
- Modify: `apps/partner/test/support/partner_journey_harness.dart`

**Interfaces:**
- Consumes Tasks 1–4.
- Produces these exact runners in `partner_journey_harness.dart`:

```dart
Future<List<PartnerJourneyResult>> runPairingLifecycleJourneys(
  WidgetTester tester,
);
Future<List<PartnerJourneyResult>> runPartnerHomeNavigationJourneys(
  WidgetTester tester,
);
Future<List<PartnerJourneyResult>> runPermissionVisibilityJourneys(
  WidgetTester tester,
);
```

- [ ] **Step 1: Write and run RED journey assertions**

Cover valid, malformed, expired, unsupported-version, scope mismatch, unavailable, and retry. Cover Now/Us/Surprise/Shared Health. Cover fully-shared raw, abstract without raw, engine-only/private/wrong-recipient hidden, VIEW-not-NOTIFY and NOTIFY-not-VIEW.

Run:

```bash
flutter test test/partner_pairing_journey_test.dart test/partner_visibility_journey_test.dart
```

Expected: failures identify missing harness runners or production UI mismatches.

- [ ] **Step 2: Add minimal runners or fix authoritative production defects**

Implement the three functions above by constructing one fresh `PartnerJourneyHarness` per scenario, calling its public label-based interaction methods, converting `observe(...)` into one `PartnerJourneyResult`, calling `cleanup()`, and returning results sorted by `scenario.id`. For a production failure, invoke systematic debugging, add a focused `widget_test.dart` or `partner_session_test.dart` regression, and fix production code rather than weakening the journey assertion.

- [ ] **Step 3: Run GREEN and regression**

Run the two journey files, all focused Partner tests, `flutter test`, and `flutter analyze`.

- [ ] **Step 4: Commit**

```bash
git add apps/partner
git commit -m "test(partner): cover pairing and visibility journeys"
```

### Task 6: Notification, revocation, and relationship-safety journeys

**Files:**
- Create: `apps/partner/test/partner_notification_journey_test.dart`
- Create: `apps/partner/test/partner_revocation_journey_test.dart`
- Create: `apps/partner/test/partner_relationship_safety_journey_test.dart`
- Modify: `apps/partner/test/support/partner_journey_harness.dart`

**Interfaces:**
- Produces these exact runners in `partner_journey_harness.dart`:

```dart
Future<List<PartnerJourneyResult>> runNotificationPrivacyJourneys(
  WidgetTester tester,
);
Future<List<PartnerJourneyResult>> runRevocationDisconnectJourneys(
  WidgetTester tester,
);
Future<List<PartnerJourneyResult>> runRelationshipSafetyJourneys(
  WidgetTester tester,
);
```

- [ ] **Step 1: Write and run RED notification tests**

Cover generic, category-only, detailed unlocked, detailed locked redacted, missing NOTIFY suppressed, and missing PLAYFUL/INTIMACY capability suppressed. Assert forbidden detail markers are absent from the entire rendered tree.

- [ ] **Step 2: Write and run RED revocation/safety tests**

Verify key rotation, notifications stopped, preview/content cleared, unpaired state, pairing retry restored, read-only UI, no invented fallback, and no consent inference from sensitive markers.

Run all three files. Expected RED is a missing runner or a concrete production mismatch.

- [ ] **Step 3: Implement minimal drivers or production fix**

Implement the three exact functions above with one fresh harness per scenario and sorted results. The harness records only UI observations and dependency effects; it must not reproduce pipeline/firewall/orchestrator decisions.

- [ ] **Step 4: Run GREEN and full Partner regression**

```bash
dart format lib test
flutter test
flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add apps/partner
git commit -m "test(partner): cover privacy and revocation journeys"
```

### Task 7: Canonical smoke and byte-stable evidence writer

**Files:**
- Create: `apps/partner/test/partner_journey_smoke_test.dart`
- Modify: `apps/partner/test/support/partner_journey_harness.dart`

**Interfaces:**
- Produces `runCanonicalPartnerJourneys(WidgetTester tester)` returning `Future<PartnerJourneyReport>`.

- [ ] **Step 1: Write smoke RED test**

In one `testWidgets`, call `runCanonicalPartnerJourneys`, cleanup, call it again with entirely fresh dependencies, compare UTF-8 JSON bytes, assert 40/40 mandatory labels, no malformed/S3/S4 findings, and write the first bytes to `partner-journey-evidence.json`.

- [ ] **Step 2: Run RED**

Run: `flutter test test/partner_journey_smoke_test.dart`

Expected: failure because the canonical runner is absent or coverage is incomplete.

- [ ] **Step 3: Implement canonical runner**

Build every scenario explicitly from RP-001/RP-002/RP-005, execute through fresh harnesses, normalize observations, apply detector/report builder, sort canonical structures, and never serialize exception text or random envelope IDs.

- [ ] **Step 4: Run GREEN twice and compare artifacts**

```bash
flutter test test/partner_journey_smoke_test.dart
cp partner-journey-evidence.json /tmp/partner-journey-first.json
flutter test test/partner_journey_smoke_test.dart
cmp /tmp/partner-journey-first.json partner-journey-evidence.json
```

Expected: both tests pass and `cmp` exits 0.

- [ ] **Step 5: Commit**

```bash
git add apps/partner/test/partner_journey_smoke_test.dart apps/partner/test/support/partner_journey_harness.dart
git commit -m "test(partner): emit canonical journey evidence"
```

### Task 8: Documentation, CI, review, merge, and post-merge gates

**Files:**
- Create: `docs/SIMULATION_PARTNER_JOURNEY.md`
- Modify: `.github/workflows/simulation-lab.yml`

**Interfaces:**
- Produces job `partner-journey`.
- Produces artifact `simulation-partner-journey-evidence` containing `apps/partner/partner-journey-evidence.json`.

- [ ] **Step 1: Write documentation**

Document architecture, six families, RP fixtures, S3/S4 model, all coverage dimensions, command, artifact, determinism, deferred device/transport scope, and synthetic-only boundary.

- [ ] **Step 2: Extend Simulation Lab workflow**

Add spec path triggers plus `apps/partner/**`, `packages/sharing/**`, `packages/permissions/**`, and `docs/SIMULATION_PARTNER_JOURNEY.md`. Add this job:

```yaml
  partner-journey:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
        working-directory: apps/partner
      - run: dart format --output=none --set-exit-if-changed lib test
        working-directory: apps/partner
      - run: flutter analyze
        working-directory: apps/partner
      - run: flutter test test/partner_journey_smoke_test.dart
        working-directory: apps/partner
      - run: flutter test
        working-directory: apps/partner
      - uses: actions/upload-artifact@v4
        with:
          name: simulation-partner-journey-evidence
          path: apps/partner/partner-journey-evidence.json
          if-no-files-found: error
          retention-days: 7
```

- [ ] **Step 3: Run local final verification**

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test test/partner_journey_smoke_test.dart
git diff --check
```

Verify evidence with a JSON parser: `syntheticEvidenceOnly == true`, passed, 40 mandatory labels, zero malformed, zero unexpected S3/S4. Record SHA-256.

- [ ] **Step 4: Commit docs and workflow**

```bash
git add docs/SIMULATION_PARTNER_JOURNEY.md .github/workflows/simulation-lab.yml
git commit -m "ci(simulation): add partner journey evidence"
```

- [ ] **Step 5: Apply completion skills and review**

Use `superpowers:verification-before-completion`, `superpowers:requesting-code-review`, and `superpowers:finishing-a-development-branch`. Resolve every Critical/Important finding with TDD and rerun local gates.

- [ ] **Step 6: Verify feature SHA remotely**

Push exact HEAD, open a PR referencing #232, and require repository CI plus Simulation Lab `foundation`, `patient-journey`, and `partner-journey` to be `completed/success` on that exact SHA. Download artifact, verify filename/content/SHA-256, and recheck #34/#58 open/reopened.

- [ ] **Step 7: Guarded merge and post-merge verification**

Merge only with expected head SHA. Require exact merge SHA repository CI and Simulation Lab to be `completed/success`; download the post-merge Partner artifact and prove byte equality with feature evidence.

- [ ] **Step 8: Close only Phase 13**

Update #232 acceptance/completion evidence and close it completed. Verify #34 and #58 remain open/reopened, human-usability TODO remains unchecked, and Phase 14 has not started.
