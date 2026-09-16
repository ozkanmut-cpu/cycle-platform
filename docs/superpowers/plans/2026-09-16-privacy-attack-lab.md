# Privacy Attack Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Phase 11 as a deterministic adversarial privacy-attack generator and containment-evidence harness that exercises Cycle's real production permission, sharing, relationship-privacy, notification, revocation, recipient-key, relay, and crypto primitives without duplicating their policy logic.

**Architecture:** Add one async Simulation Lab domain module, `privacy_attack.dart`, whose models, deterministic generator, production adapter, detector, coverage gate, canonical corpus, and smoke runner follow the existing Phase 8–10 patterns. The adapter calls production engines directly; the detector checks only minimal observable containment contracts. Relay/crypto paths are async because `AuthenticatedCipher` and `SharingTransport` are async, and canonical evidence records only stable booleans/reason categories—not nonce, ciphertext, key bytes, host data, or stack paths.

**Tech Stack:** Dart >=3.6, `test`, existing `cycle_permissions`, `cycle_sharing`, `cycle_crypto`, Simulation Lab canonical JSON conventions, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-16-privacy-attack-lab-design.md`

## Global Constraints

- Base branch is `main` at Phase 10 merge SHA `81e72ba4fb722dbcedd7d38835a483c3d98f0a9d`; work only on `phase-11-privacy-attack-lab` until guarded merge.
- Never modify `/opt/field-maintenance/app` or any field-maintenance production path; Cycle worktree operations are restricted to `/tmp/cycle-*`.
- Production engines remain authoritative. Simulation code may mutate inputs and normalize observations but must not reproduce grant matching, visibility ranking, notification rendering, key-rotation rules, relay validation, or crypto validation.
- Every confirmed privacy-boundary breach is severity `InvariantSeverity.s4`.
- `PrivacyAttackObserver.observe` is asynchronous from Task 1 onward: `Future<PrivacyAttackObservation> observe(PrivacyAttackScenario scenario)`.
- Canonical evidence must contain only stable values. Do not serialize nonce, ciphertext, authentication tags, raw key bytes, wall-clock time, host paths, environment values, process IDs, or stack traces.
- Production smoke uses `ProductionPrivacyAttackObserver` only. Test-only injected observers are allowed only in detector self-tests.
- If an attack exposes a real production defect, stop that task, use `superpowers:systematic-debugging`, add a focused regression test in the authoritative production package, fix production there, then rerun the privacy-attack test. Do not mask the defect in simulation code.
- Phase 11 does not absorb Phase 16 wrong-patient safety, Phase 21 AI red-team expansion, Phase 22 Clinical + Playful collision breadth, general-purpose fuzzing, metamorphic testing, mutation testing, or human usability testing.
- Issue #58 must remain `open/reopened`; synthetic evidence never satisfies it.
- A workflow that is queued, pending, or in progress is not green. Exact feature SHA and exact merge SHA must each reach `completed/success` for repository CI and Simulation Lab.

---

## File Structure

- Create `packages/simulation_domain/lib/src/privacy_attack.dart`: versioned models, async suite/detector, deterministic attack generator, production adapter, fixture conversion helpers, canonical corpus, coverage gates, and `runProductionPrivacyAttackSmoke`.
- Modify `packages/simulation_domain/lib/simulation_domain.dart`: export the Phase 11 module.
- Modify `packages/simulation_domain/pubspec.yaml`: add direct `cycle_crypto` path dependency for the production AES-GCM primitive used by relay attacks.
- Create `packages/simulation_domain/test/privacy_attack_test.dart`: all Phase 11 model, generator, production-containment, detector, determinism, and coverage tests.
- Create `packages/simulation_domain/bin/privacy_attack_smoke.dart`: async production-only CLI.
- Create `docs/SIMULATION_PRIVACY_ATTACK.md`: Phase 11 public architecture/evidence contract.
- Modify `.github/workflows/simulation-lab.yml`: path trigger, smoke command, exact artifact upload.
- Keep `packages/permissions/**`, `packages/sharing/**`, and `packages/crypto/**` unchanged unless a Phase 11 attack proves a real production defect; if so, add the smallest production regression/fix in the owning package.

---

### Task 1: Core async privacy-attack model, detector, report, and serialization

**Files:**
- Create: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/lib/simulation_domain.dart`
- Test: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- Produces `privacyAttackSchemaVersion = 1`.
- Produces enum `PrivacyAttackFamily { identitySubstitution, actionEscalation, scopeSubstitution, temporalReplay, composedGrantConfusion, relationshipCapabilityEscalation, visibilityExfiltration, notificationLeakage, revocationAndKeyReplay, relayRecipientBinding }`.
- Produces enum `PrivacyContainmentContract { denyAuthority, denyProjection, noRawExposure, redactOrSuppressNotification, requireKeyRotation, rejectRelayDecrypt, rejectRelayIntegrityTamper }`.
- Produces `PrivacyAttackMutation`, `PrivacyAttackScenario`, `PrivacyAttackObservation`, `PrivacyAttackResult`, `PrivacyAttackCoverage`, `PrivacyAttackReport`.
- Produces abstract `PrivacyAttackObserver` with `Future<PrivacyAttackObservation> observe(PrivacyAttackScenario scenario)`.
- Produces `PrivacyAttackSuite.evaluate({required int seed, required Iterable<PrivacyAttackScenario> scenarios, required PrivacyAttackObserver observer, bool requireMandatoryCoverage = false}) -> Future<PrivacyAttackReport>`.
- `PrivacyAttackReport.toNormalizedJson()` returns canonical `jsonEncode` output with sorted results/maps and `syntheticEvidenceOnly: true`.

- [ ] **Step 1: Write the failing core model/round-trip/detector tests**

Add tests that construct one UTC scenario and assert validation, round-trip, canonical order, and impossible-observation detection:

```dart
final at = DateTime.utc(2026, 9, 16, 12);
final mutation = PrivacyAttackMutation(
  id: 'mut-wrong-recipient',
  family: PrivacyAttackFamily.identitySubstitution,
  sourceControlId: 'control-view',
  dimensions: const <String>{'recipient'},
  before: const <String, Object?>{'recipientId': 'partner-1'},
  after: const <String, Object?>{'recipientId': 'partner-2'},
  paired: false,
);
final scenario = PrivacyAttackScenario(
  id: 'attack-wrong-recipient',
  schemaVersion: privacyAttackSchemaVersion,
  seed: 20260916,
  at: at,
  ownerId: 'patient-1',
  intendedRecipientId: 'partner-1',
  attemptedRecipientId: 'partner-2',
  family: PrivacyAttackFamily.identitySubstitution,
  targetSurface: 'genericPermission',
  mutation: mutation,
  containmentContract: PrivacyContainmentContract.denyAuthority,
  riskTags: const <String>{'identity', 'recipient', 'phase9Reuse'},
  payload: const <String, Object?>{},
  adversarial: true,
);
expect(
  PrivacyAttackScenario.fromJson(scenario.toJson()).toJson(),
  scenario.toJson(),
);
```

Add an injected observer returning `allowed: true` for `denyAuthority`; assert the suite returns `passed == false`, `severity == InvariantSeverity.s4`, and stable finding category `identity_scope_escape`.

- [ ] **Step 2: Run the focused test and verify RED**

Run from repo root:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart pub get && dart test test/privacy_attack_test.dart -r expanded'
```

Expected: compile failure because Phase 11 types do not exist.

- [ ] **Step 3: Implement the minimal core types and async suite**

Use stable required-field validation and an async observer:

```dart
const int privacyAttackSchemaVersion = 1;

abstract class PrivacyAttackObserver {
  const PrivacyAttackObserver();
  Future<PrivacyAttackObservation> observe(PrivacyAttackScenario scenario);
}

class PrivacyAttackSuite {
  const PrivacyAttackSuite();

  Future<PrivacyAttackReport> evaluate({
    required int seed,
    required Iterable<PrivacyAttackScenario> scenarios,
    required PrivacyAttackObserver observer,
    bool requireMandatoryCoverage = false,
  }) async {
    final ordered = scenarios.toList()..sort((a, b) => a.id.compareTo(b.id));
    final results = <PrivacyAttackResult>[];
    for (final scenario in ordered) {
      try {
        final observation = await observer.observe(scenario);
        results.add(_evaluateContainment(scenario, observation));
      } catch (_) {
        results.add(PrivacyAttackResult.malformed(scenario));
      }
    }
    return PrivacyAttackReport.fromRun(
      seed: seed,
      scenarios: ordered,
      results: results,
      requireMandatoryCoverage: requireMandatoryCoverage,
    );
  }
}
```

`_evaluateContainment` must switch only on `PrivacyContainmentContract` and normalized observation fields. It must not inspect grants or duplicate production policy.

- [ ] **Step 4: Implement canonical JSON and finding-category mapping**

Map family breaches deterministically:

```dart
String _findingCategory(PrivacyAttackScenario scenario) => switch (scenario.family) {
  PrivacyAttackFamily.identitySubstitution => 'identity_scope_escape',
  PrivacyAttackFamily.actionEscalation => 'action_escalation',
  PrivacyAttackFamily.scopeSubstitution => 'scope_escape',
  PrivacyAttackFamily.temporalReplay => 'temporal_replay_escape',
  PrivacyAttackFamily.composedGrantConfusion => 'composed_gate_bypass',
  PrivacyAttackFamily.relationshipCapabilityEscalation =>
    'relationship_capability_escalation',
  PrivacyAttackFamily.visibilityExfiltration => 'visibility_exfiltration',
  PrivacyAttackFamily.notificationLeakage => 'notification_privacy_violation',
  PrivacyAttackFamily.revocationAndKeyReplay => 'revocation_escape',
  PrivacyAttackFamily.relayRecipientBinding => 'relay_recipient_bypass',
};
```

Represent malformed input as `malformed_input` and missing coverage as `coverage_gap`. Keep all breach severities S4.

- [ ] **Step 5: Run focused tests and format**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart format lib/src/privacy_attack.dart lib/simulation_domain.dart test/privacy_attack_test.dart && dart test test/privacy_attack_test.dart -r expanded'
```

Expected: PASS.

- [ ] **Step 6: Commit Task 1**

```bash
git add packages/simulation_domain/lib/src/privacy_attack.dart packages/simulation_domain/lib/simulation_domain.dart packages/simulation_domain/test/privacy_attack_test.dart
git commit -m "feat(simulation): add privacy attack core model"
```

---

### Task 2: Deterministic generator and generic permission attacks A-D

**Files:**
- Modify: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- Produces `PrivacyAttackGenerator.generateCanonical(int seed) -> List<PrivacyAttackScenario>`.
- Extends `ProductionPrivacyAttackObserver` with target surfaces `genericPermission` and `sharePolicy`.
- Reuses production `PermissionEvaluator`, `PrivacySimulator`, and `SharePolicy`.
- Covers identity substitution, generic action escalation, scope substitution, and temporal/data-window replay.

- [ ] **Step 1: Write failing generator and A-D production tests**

Add tests asserting:

```dart
final first = PrivacyAttackGenerator().generateCanonical(20260916);
final second = PrivacyAttackGenerator().generateCanonical(20260916);
expect(first.map((e) => e.toJson()).toList(), second.map((e) => e.toJson()).toList());
expect(first.every((e) => e.sourceControlId.isNotEmpty), isTrue);
```

Add production-containment tests for:
- owner/recipient substitution;
- VIEW -> NOTIFY/BACKUP/EXPORT and inverse narrow-action attempts;
- wrong category, field, and purpose;
- before activation, exact expiry, exact revocation, after revocation;
- before `dataFrom`, at `dataFrom`, at `dataUntil`, after `dataUntil`.

Use safe-control + mutated attack pairs sharing a stable `sourceControlId`.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart test test/privacy_attack_test.dart -r expanded'
```

Expected: failures because generator/production observer support does not exist.

- [ ] **Step 3: Implement `ProductionPrivacyAttackObserver` generic dispatch**

Use direct production calls:

```dart
class ProductionPrivacyAttackObserver extends PrivacyAttackObserver {
  const ProductionPrivacyAttackObserver({
    this.permissionEvaluator = const PermissionEvaluator(),
    this.privacySimulator = const PrivacySimulator(),
    this.sharePolicy = const SharePolicy(),
  });

  final PermissionEvaluator permissionEvaluator;
  final PrivacySimulator privacySimulator;
  final SharePolicy sharePolicy;

  @override
  Future<PrivacyAttackObservation> observe(PrivacyAttackScenario scenario) async {
    return switch (scenario.targetSurface) {
      'genericPermission' => _observeGenericPermission(scenario),
      'sharePolicy' => _observeSharePolicy(scenario),
      _ => throw ArgumentError('Unsupported target surface'),
    };
  }
}
```

For generic requests, call both `PermissionEvaluator.evaluate` and `PrivacySimulator.simulate` and throw deterministic validation error if they diverge, matching Phase 9's cross-check behavior.

- [ ] **Step 4: Implement deterministic A-D mutation templates**

Build controls with fixed IDs and UTC timestamps. Mutate only the named dimensions. Do not derive expected allow/deny decisions by matching grants in simulation code; assign only the containment contract (`denyAuthority`) to adversarial cases and let production determine the observation.

- [ ] **Step 5: Run A-D tests and the whole Phase 9 permission-flow regression set**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart test test/privacy_attack_test.dart test/permission_flow_test.dart -r expanded'
```

Expected: PASS.

- [ ] **Step 6: Commit Task 2**

```bash
git add packages/simulation_domain/lib/src/privacy_attack.dart packages/simulation_domain/test/privacy_attack_test.dart
git commit -m "feat(simulation): generate generic privacy attacks"
```

---

### Task 3: Composed authorization, relationship capability, visibility, and notification attacks E-H

**Files:**
- Modify: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- Extends `ProductionPrivacyAttackObserver` with target surfaces `composedAccess`, `relationshipPermission`, `relationshipProjection`, and `relationshipNotification`.
- Reuses `RelationshipAccessGate`, `RelationshipPermissionFirewall`, `RelationshipContextProjector`, and `RelationshipNotificationPipeline`.
- Covers attack families E-H.

- [ ] **Step 1: Write failing E-H production tests**

Add tests for:
- generic grant recipient A + relationship grant recipient B;
- correct recipient but wrong relationship category;
- relationship capability present with missing generic action;
- view -> relationshipIntelligence/playful/intimacy escalation;
- notify -> playful/intimacy; playful -> intimacy;
- private/engineOnly/abstractShared raw-value exfiltration;
- fullyShared grant plus more restrictive item visibility;
- generic/categoryOnly/detailedWhenUnlocked notification modes;
- locked detailed notification;
- playful/intimacy/playfulIntimacy missing content capabilities;
- content capability present without notify;
- wrong-recipient notification grant.

Example assertion:

```dart
final report = await const PrivacyAttackSuite().evaluate(
  seed: 20260916,
  scenarios: <PrivacyAttackScenario>[scenario],
  observer: const ProductionPrivacyAttackObserver(),
);
expect(report.results.single.passed, isTrue);
expect(report.results.single.observation.rawValueExposed, isFalse);
```

- [ ] **Step 2: Run focused tests and verify RED**

Use the standard container command. Expected: unsupported target-surface failures.

- [ ] **Step 3: Add production adapters for E-G**

Map fixture payloads into real production types, then normalize only observed outputs. For projections, return `projected`, `rawValueExposed`, and `effectiveVisibility`; do not copy `_mostRestrictive` logic from production.

- [ ] **Step 4: Add production adapter for H notifications**

Call `RelationshipNotificationPipeline.present` and normalize:

```dart
return PrivacyAttackObservation(
  notificationEmitted: notification != null,
  notificationRedacted: notification?.redacted,
  notificationBodyClass: notification == null
      ? 'suppressed'
      : notification.redacted
          ? 'redacted'
          : 'detailed',
);
```

Do not serialize the private detail body into evidence.

- [ ] **Step 5: Add deterministic E-H mutation templates and run Phase 9/10 regressions**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart test test/privacy_attack_test.dart test/permission_flow_test.dart test/relationship_behavior_test.dart -r expanded'
```

Expected: PASS.

- [ ] **Step 6: Commit Task 3**

```bash
git add packages/simulation_domain/lib/src/privacy_attack.dart packages/simulation_domain/test/privacy_attack_test.dart
git commit -m "feat(simulation): attack relationship privacy surfaces"
```

---

### Task 4: Revocation, recipient-key replay, and relay binding attacks I-J

**Files:**
- Modify: `packages/simulation_domain/pubspec.yaml`
- Modify: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/test/privacy_attack_test.dart`
- Conditional only if a real defect is proven: focused files/tests under `packages/sharing/**` or `packages/crypto/**`.

**Interfaces:**
- Adds direct dependency:

```yaml
  cycle_crypto:
    path: ../crypto
```

- Extends observer with target surfaces `revocationKeyState` and `relayTransport`.
- Reuses `SharingRevocationCoordinator`, `RecipientKeyRegistry`, `AesGcmAuthenticatedCipher`, `SharingTransport`, and `OpaqueRelayEnvelope`.
- Uses fixed 32-byte key material derived from fixture ID, but never emits key bytes or crypto envelope bytes into canonical evidence.

- [ ] **Step 1: Write failing I-J tests**

Cover:
- revoked grant remains denied after exact revocation;
- `SharingRevocationCoordinator` reports key rotation and notification stop where production says so;
- `RecipientKeyRegistry.rotate` revokes prior active state and increments version;
- stale key-state attempt does not become active authority;
- safe relay encrypt/decrypt succeeds for the correct recipient;
- wrong-recipient decrypt is rejected;
- outer-recipient/envelope-integrity tampering is rejected when production validation binds it;
- tampered authenticated ciphertext/associated-data is rejected by production AES-GCM.

The test must assert stable booleans only, never nonce/ciphertext equality.

- [ ] **Step 2: Run focused tests and verify RED**

Expected initially: missing `cycle_crypto` direct dependency and unsupported target surfaces.

- [ ] **Step 3: Add `cycle_crypto` dependency and production AES-GCM fixture**

Use real production AES-GCM with a deterministic resolver:

```dart
AesGcmAuthenticatedCipher _fixtureCipher() => AesGcmAuthenticatedCipher(
  keyResolver: (keyEnvelopeId) async =>
      List<int>.generate(32, (index) => (index + keyEnvelopeId.length) & 0xff),
);
```

Random AES-GCM nonce generation is acceptable internally because nonce/ciphertext/tag never enter normalized evidence; the observable containment result remains deterministic.

- [ ] **Step 4: Implement revocation/key adapter**

Create a local `RecipientKeyRegistry`, seed it from fixture payload, adapt it to `RecipientKeyRotator`, invoke `SharingRevocationCoordinator.revoke`, then normalize only key version/revoked-state/notification-stop/export-invalidation observations exposed by production APIs.

- [ ] **Step 5: Implement relay adapter**

Use `SharingTransport(_fixtureCipher())`. Build a safe envelope with `encryptForRecipient`, then apply the scenario mutation and call `decryptForRecipient`. Normalize `relayDecryptAccepted` and `relayIntegrityAccepted` only.

For tampering, construct a new `CiphertextEnvelope`/`OpaqueRelayEnvelope` from the production envelope with the single named mutated field. Do not reimplement GCM verification.

- [ ] **Step 6: If a containment assertion reveals a production defect, fix it in the authoritative package**

Before changing production code, invoke `superpowers:systematic-debugging`. Add a focused regression in the owning package that reproduces the exact privacy defect through the public production API. Make the smallest production fix, run the owning package tests, then rerun the Phase 11 attack test. Never weaken the Phase 11 containment assertion.

- [ ] **Step 7: Run I-J and related production package regressions**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart pub get && dart test test/privacy_attack_test.dart -r expanded'
```

If production files changed, also run their package test suites from the same repo-root-mounted container.

- [ ] **Step 8: Commit Task 4**

```bash
git add packages/simulation_domain/pubspec.yaml packages/simulation_domain/lib/src/privacy_attack.dart packages/simulation_domain/test/privacy_attack_test.dart
git add packages/sharing packages/crypto 2>/dev/null || true
git commit -m "feat(simulation): attack revocation and relay privacy"
```

Before committing, inspect `git status --short` and remove untracked generated lockfiles such as `packages/simulation_domain/pubspec.lock` unless already tracked by the repository.

---

### Task 5: Mandatory coverage gates, detector self-tests, and canonical production corpus

**Files:**
- Modify: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- Produces `buildCanonicalPrivacyAttackScenarios(int seed) -> List<PrivacyAttackScenario>`.
- Produces mandatory coverage validation for all 10 families, all four generic actions, category/field/purpose, activation/expiry/revocation/data-window, all relationship capabilities, all visibility contexts, all notification privacy modes, revocation/key, relay, safe/adversarial, and Phase 8/9/10 reuse markers.
- Produces detector self-tests for all stable S4 finding categories without injecting impossible observations into production smoke.

- [ ] **Step 1: Write failing coverage and detector tests**

Assert every family is present and that deleting one family produces a deterministic `coverage_gap` failure. Inject impossible observations for each containment contract/finding category and assert S4 failure.

- [ ] **Step 2: Run focused tests and verify RED**

Expected: missing mandatory coverage/canonical corpus behavior.

- [ ] **Step 3: Build the final risk-oriented canonical corpus**

Keep safe-control + attack linkage, exact UTC timestamps, stable IDs, and selected pairwise cases only. Sort final scenarios by stable ID before evaluation.

- [ ] **Step 4: Implement mandatory coverage gap calculation**

Use sorted stable gap labels such as:

```dart
'family:${family.name}'
'action:view'
'scope:purpose'
'temporal:revocation'
'visibility:engineOnly'
'notification:detailedWhenUnlocked'
'surface:relay'
'reuse:phase9'
```

Any missing label creates S4 `coverage_gap` evidence and makes the report fail.

- [ ] **Step 5: Prove input permutation does not change canonical report bytes**

Evaluate the same corpus forward and reversed with the same seed; assert `toNormalizedJson()` equality.

- [ ] **Step 6: Run full `simulation_domain` tests**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart pub get && dart test'
```

Expected: all tests PASS.

- [ ] **Step 7: Commit Task 5**

```bash
git add packages/simulation_domain/lib/src/privacy_attack.dart packages/simulation_domain/test/privacy_attack_test.dart
git commit -m "feat(simulation): add canonical privacy attack matrix"
```

---

### Task 6: Production smoke, documentation, and Simulation Lab CI artifact

**Files:**
- Create: `packages/simulation_domain/bin/privacy_attack_smoke.dart`
- Create: `docs/SIMULATION_PRIVACY_ATTACK.md`
- Modify: `.github/workflows/simulation-lab.yml`
- Modify: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- Produces `Future<PrivacyAttackReport> runProductionPrivacyAttackSmoke(int seed)`.
- CLI invocation: `dart run bin/privacy_attack_smoke.dart --seed=20260916`.
- CI output file: `privacy-attack-evidence.json`.
- Exact artifact: `simulation-privacy-attack-evidence`.

- [ ] **Step 1: Write the failing smoke contract test**

Test `runProductionPrivacyAttackSmoke(20260916)` twice and assert:

```dart
final first = await runProductionPrivacyAttackSmoke(20260916);
final second = await runProductionPrivacyAttackSmoke(20260916);
expect(first.passed, isTrue);
expect(first.coverage.malformedInputFailures, 0);
expect(first.toNormalizedJson(), second.toNormalizedJson());
```

- [ ] **Step 2: Run focused test and verify RED**

Expected: smoke runner does not exist.

- [ ] **Step 3: Implement the async smoke runner and CLI**

```dart
Future<void> main(List<String> args) async {
  final seedArg = args.where((item) => item.startsWith('--seed=')).firstOrNull;
  final seed = int.tryParse(seedArg?.substring('--seed='.length) ?? '') ?? 20260916;
  final report = await runProductionPrivacyAttackSmoke(seed);
  if (!report.passed) {
    throw StateError('Privacy-attack production smoke contains contract failures');
  }
  print(report.toNormalizedJson());
}
```

`runProductionPrivacyAttackSmoke` must use `ProductionPrivacyAttackObserver` and mandatory coverage. No injected observer is allowed.

- [ ] **Step 4: Add `docs/SIMULATION_PRIVACY_ATTACK.md`**

Document production authority, A-J attack families, detector limits, async crypto/relay handling, canonical evidence, coverage gates, smoke command/artifact, deferred Phase 16/21/22/general-fuzzing scope, and Issue #58 boundary.

- [ ] **Step 5: Extend `.github/workflows/simulation-lab.yml`**

Add `docs/SIMULATION_PRIVACY_ATTACK.md` to both path-filter sections, then add after Phase 10 smoke:

```yaml
      - name: Privacy attack smoke
        run: dart run bin/privacy_attack_smoke.dart --seed=20260916 > privacy-attack-evidence.json
        working-directory: packages/simulation_domain
```

Add exact artifact upload:

```yaml
      - name: Upload privacy attack evidence
        uses: actions/upload-artifact@v4
        with:
          name: simulation-privacy-attack-evidence
          path: packages/simulation_domain/privacy-attack-evidence.json
          if-no-files-found: error
          retention-days: 7
```

- [ ] **Step 6: Run fresh local verification gate**

From repo root:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc '
  dart pub get &&
  dart format --output=none --set-exit-if-changed lib test bin &&
  dart analyze . &&
  dart test &&
  dart run bin/privacy_attack_smoke.dart --seed=20260916 > /tmp/privacy-a.json &&
  dart run bin/privacy_attack_smoke.dart --seed=20260916 > /tmp/privacy-b.json &&
  cmp /tmp/privacy-a.json /tmp/privacy-b.json
'
```

Also parse `/tmp/privacy-a.json` and assert `passed=true`, `syntheticEvidenceOnly=true`, zero malformed failures, all ten families, and mandatory dimensions.

- [ ] **Step 7: Run YAML/diff/hygiene checks**

Validate workflow YAML with an available YAML parser, run `git diff --check`, scan changed files for real `TBD`/`FIXME`/placeholder markers, and verify the diff contains no `/opt/field-maintenance/app` or field-maintenance production file path.

- [ ] **Step 8: Commit Task 6**

```bash
git add packages/simulation_domain/bin/privacy_attack_smoke.dart packages/simulation_domain/test/privacy_attack_test.dart docs/SIMULATION_PRIVACY_ATTACK.md .github/workflows/simulation-lab.yml
git commit -m "ci(simulation): publish privacy attack evidence"
```

---

### Task 7: Exact-SHA review, PR, CI/artifact verification, guarded merge, and Phase 11 closure

**Files:**
- No planned product-code changes after the final verified feature tree.
- Update GitHub Issue #228 evidence/checklist only after post-merge verification.

**Interfaces:**
- Feature branch: `phase-11-privacy-attack-lab`.
- Issue: #228.
- Human usability blocker: #58 must remain `open/reopened`.
- Artifact: `simulation-privacy-attack-evidence`.

- [ ] **Step 1: Read `superpowers:requesting-code-review` and `superpowers:verification-before-completion`**

Perform a focused review against the spec and #228 acceptance criteria. Review specifically for copied policy logic, incomplete attack-family coverage, secret material in evidence, nondeterministic crypto data in JSON, and missing Issue #58 boundary.

- [ ] **Step 2: Run one final fresh local verification on the exact candidate tree**

Repeat Task 6 Step 6 plus `git diff --check`, changed-file scope check, and clean status check. Record test count and canonical JSON SHA-256 from this exact tree.

- [ ] **Step 3: Publish the exact final feature tree**

If normal git push is unavailable, use GitHub Git Data/Contents APIs. After publishing, compare every changed file blob or final root tree so the remote branch content is byte-identical to the locally verified tree. Treat the remote commit SHA as the canonical feature SHA.

- [ ] **Step 4: Open/update the Phase 11 PR**

PR body must include #228, exact feature SHA/tree, local test count, canonical evidence counts/hash, artifact name, synthetic-evidence boundary, and #58 status.

- [ ] **Step 5: Verify exact feature SHA CI**

Wait until both repository CI and Simulation Lab for the exact feature SHA are `completed/success`. Do not accept runs for an earlier commit.

- [ ] **Step 6: Download and independently verify the feature artifact**

Confirm artifact name `simulation-privacy-attack-evidence`, artifact head SHA equals the exact feature SHA, JSON parses, canonical JSON SHA-256 matches local evidence, `passed=true`, `syntheticEvidenceOnly=true`, zero malformed failures, and mandatory coverage is complete.

- [ ] **Step 7: Re-fetch #58 and guarded-merge the PR**

Immediately before merge, assert #58 is `open/reopened`, PR head is still the verified feature SHA, base is expected `main`, and `main` has not moved unexpectedly. Merge only with an expected-head/base guard.

- [ ] **Step 8: Verify exact merge SHA on `main`**

Assert `main` equals the returned merge SHA and the merge tree contains the verified feature tree/content.

- [ ] **Step 9: Verify post-merge repository CI and Simulation Lab**

For the exact merge SHA with `event=push`, require both workflows `completed/success`.

- [ ] **Step 10: Download and independently verify the post-merge artifact**

Confirm artifact name/head SHA/content and canonical evidence hash/counts exactly as required by the spec.

- [ ] **Step 11: Update and close Issue #228**

Mark acceptance criteria `[x]` only when backed by the feature/post-merge evidence. Append exact feature SHA/tree, PR, merge SHA, workflow run IDs, artifact IDs/digests, canonical JSON SHA-256, test count, and synthetic-evidence boundary. Close with state reason `completed`.

- [ ] **Step 12: Final invariants**

Re-fetch #228 (`closed/completed`), #58 (`open/reopened`), PR (`merged=true`), and `main` (exact merge SHA). Only then declare Phase 11 complete. Stop; do not begin Phase 12 in the same phase-completion turn.
