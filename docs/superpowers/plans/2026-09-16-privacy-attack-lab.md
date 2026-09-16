# Privacy Attack Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Phase 11 as a deterministic adversarial privacy-attack generator and containment-evidence harness that exercises Cycle's real production permission, sharing, relationship-privacy, notification, revocation, recipient-key, relay, and crypto primitives without duplicating policy logic.

**Architecture:** Add one async Simulation Lab module, `privacy_attack.dart`, containing versioned models, a deterministic safe-control/attack generator, a production adapter, a minimal containment detector, coverage gates, and the canonical smoke corpus. Production engines decide allow/deny/redaction/key/relay behavior; Simulation Lab only mutates inputs and evaluates observable containment contracts. Relay/crypto paths are async because production `AuthenticatedCipher` and `SharingTransport` APIs are async.

**Tech Stack:** Dart >=3.6, `test`, `cycle_permissions`, `cycle_sharing`, direct `cycle_crypto`, existing Simulation Lab canonical JSON conventions, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-16-privacy-attack-lab-design.md`

## Global Constraints

- Base is Phase 10 merge SHA `81e72ba4fb722dbcedd7d38835a483c3d98f0a9d`; all Phase 11 work stays on `phase-11-privacy-attack-lab` until guarded merge.
- Never modify `/opt/field-maintenance/app` or any field-maintenance production path. Cycle worktree activity is restricted to `/tmp/cycle-*`.
- Production packages remain authoritative. Simulation code must not reimplement grant matching, relationship visibility ranking, notification rendering, key-rotation policy, relay binding policy, or cryptographic validation.
- Every confirmed privacy-boundary breach is `InvariantSeverity.s4`.
- `PrivacyAttackObserver.observe` is async from the first implementation: `Future<PrivacyAttackObservation> observe(PrivacyAttackScenario scenario)`.
- Canonical evidence never serializes nonce, ciphertext, authentication tag, plaintext secret data, key bytes, wall-clock time, host paths, environment values, process IDs, or stack traces.
- Production smoke uses `ProductionPrivacyAttackObserver` only. Injected observers are test-only for detector self-tests.
- If a Phase 11 attack exposes a real production defect, stop that task, invoke `superpowers:systematic-debugging`, add a focused regression in the authoritative production package, fix the defect there, and rerun the attack. Never weaken or bypass the Phase 11 detector.
- Phase 16 wrong-patient safety, Phase 21 AI red-team breadth, Phase 22 Clinical + Playful collisions, general fuzzing, metamorphic testing, mutation testing, and human usability remain deferred.
- Issue #58 must stay `open/reopened`; Phase 11 evidence is synthetic only.
- Queued/pending/in-progress CI is never green. Feature SHA and merge SHA must each reach `completed/success` for repository CI and Simulation Lab.

---

## File Structure

- Create `packages/simulation_domain/lib/src/privacy_attack.dart` — Phase 11 model, generator, production adapter, detector, canonical corpus, coverage, smoke runner.
- Modify `packages/simulation_domain/lib/simulation_domain.dart` — export `privacy_attack.dart`.
- Modify `packages/simulation_domain/pubspec.yaml` — add direct `cycle_crypto` path dependency.
- Create `packages/simulation_domain/test/privacy_attack_test.dart` — Phase 11 tests.
- Create `packages/simulation_domain/bin/privacy_attack_smoke.dart` — async production-only smoke CLI.
- Create `docs/SIMULATION_PRIVACY_ATTACK.md` — architecture/evidence documentation.
- Modify `.github/workflows/simulation-lab.yml` — path trigger, smoke, exact artifact upload.
- Modify production files only if a failing attack proves a production defect; then change only the exact owning files plus focused regression tests.

---

### Task 1: Core async model, detector, report, and canonical serialization

**Files:**
- Create: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/lib/simulation_domain.dart`
- Test: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- `privacyAttackSchemaVersion = 1`
- `PrivacyAttackFamily { identitySubstitution, actionEscalation, scopeSubstitution, temporalReplay, composedGrantConfusion, relationshipCapabilityEscalation, visibilityExfiltration, notificationLeakage, revocationAndKeyReplay, relayRecipientBinding }`
- `PrivacyContainmentContract { allowAuthority, denyAuthority, allowProjection, denyProjection, allowRawExposure, noRawExposure, emitNotification, redactOrSuppressNotification, requireKeyRotation, allowRelayDecrypt, rejectRelayDecrypt, rejectRelayIntegrityTamper }`
- `PrivacyAttackMutation`, `PrivacyAttackScenario`, `PrivacyAttackObservation`, `PrivacyAttackResult`, `PrivacyAttackCoverage`, `PrivacyAttackReport`
- `abstract class PrivacyAttackObserver { Future<PrivacyAttackObservation> observe(PrivacyAttackScenario scenario); }`
- `Future<PrivacyAttackReport> PrivacyAttackSuite.evaluate({required int seed, required Iterable<PrivacyAttackScenario> scenarios, required PrivacyAttackObserver observer, bool requireMandatoryCoverage = false})`

- [ ] **Step 1: Write failing model/round-trip/async detector tests**

Use a UTC scenario and mutation:

```dart
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
  at: DateTime.utc(2026, 9, 16, 12),
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
expect(PrivacyAttackScenario.fromJson(scenario.toJson()).toJson(), scenario.toJson());
```

Add two test-only observers: one returns `allowed: false` and must pass `denyAuthority`; one returns `allowed: true` and must produce S4 `identity_scope_escape`.

- [ ] **Step 2: Run focused test and verify RED**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart pub get && dart test test/privacy_attack_test.dart -r expanded'
```

Expected: compile failure because Phase 11 types do not exist.

- [ ] **Step 3: Implement minimal validated models and async suite**

Core shape:

```dart
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

`PrivacyAttackObservation` must expose only normalized stable fields needed by contracts: nullable `allowed`, `projected`, `rawValueExposed`, `notificationEmitted`, `notificationRedacted`, `keyRotated`, `staleKeyActive`, `relayDecryptAccepted`, `relayIntegrityAccepted`, plus stable grant IDs/visibility/reason strings where production exposes them.

- [ ] **Step 4: Implement positive safe-control and negative attack contracts**

`_evaluateContainment` switches only on `PrivacyContainmentContract` and observation fields. Examples:

```dart
PrivacyContainmentContract.allowAuthority => observation.allowed == true,
PrivacyContainmentContract.denyAuthority => observation.allowed == false,
PrivacyContainmentContract.allowProjection => observation.projected == true,
PrivacyContainmentContract.denyProjection => observation.projected == false,
PrivacyContainmentContract.allowRawExposure => observation.rawValueExposed == true,
PrivacyContainmentContract.noRawExposure => observation.rawValueExposed == false,
PrivacyContainmentContract.emitNotification => observation.notificationEmitted == true,
PrivacyContainmentContract.redactOrSuppressNotification =>
  observation.notificationEmitted == false || observation.notificationRedacted == true,
PrivacyContainmentContract.requireKeyRotation => observation.keyRotated == true,
PrivacyContainmentContract.allowRelayDecrypt => observation.relayDecryptAccepted == true,
PrivacyContainmentContract.rejectRelayDecrypt => observation.relayDecryptAccepted == false,
PrivacyContainmentContract.rejectRelayIntegrityTamper =>
  observation.relayIntegrityAccepted == false,
```

- [ ] **Step 5: Implement stable finding-category mapping and canonical JSON**

Use family plus contract where one family has multiple S4 categories:

```dart
String _findingCategory(PrivacyAttackScenario scenario) {
  if (scenario.family == PrivacyAttackFamily.revocationAndKeyReplay &&
      scenario.containmentContract == PrivacyContainmentContract.requireKeyRotation) {
    return 'stale_key_escape';
  }
  if (scenario.family == PrivacyAttackFamily.relayRecipientBinding &&
      scenario.containmentContract == PrivacyContainmentContract.rejectRelayIntegrityTamper) {
    return 'relay_integrity_violation';
  }
  return switch (scenario.family) {
    PrivacyAttackFamily.identitySubstitution => 'identity_scope_escape',
    PrivacyAttackFamily.actionEscalation => 'action_escalation',
    PrivacyAttackFamily.scopeSubstitution => 'scope_escape',
    PrivacyAttackFamily.temporalReplay => 'temporal_replay_escape',
    PrivacyAttackFamily.composedGrantConfusion => 'composed_gate_bypass',
    PrivacyAttackFamily.relationshipCapabilityEscalation => 'relationship_capability_escalation',
    PrivacyAttackFamily.visibilityExfiltration => 'visibility_exfiltration',
    PrivacyAttackFamily.notificationLeakage => 'notification_privacy_violation',
    PrivacyAttackFamily.revocationAndKeyReplay => 'revocation_escape',
    PrivacyAttackFamily.relayRecipientBinding => 'relay_recipient_bypass',
  };
}
```

Malformed input is `malformed_input`; missing coverage is `coverage_gap`. Reports sort results/maps and serialize `syntheticEvidenceOnly: true`.

- [ ] **Step 6: Run focused tests and format**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart format lib/src/privacy_attack.dart lib/simulation_domain.dart test/privacy_attack_test.dart && dart test test/privacy_attack_test.dart -r expanded'
```

Expected: PASS.

- [ ] **Step 7: Commit Task 1**

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
- `PrivacyAttackGenerator.generateCanonical(int seed) -> List<PrivacyAttackScenario>`
- `ProductionPrivacyAttackObserver` gains `genericPermission` and `sharePolicy` target surfaces.
- Reuses `PermissionEvaluator`, `PrivacySimulator`, `SharePolicy`.

- [ ] **Step 1: Write failing generator stability and A-D containment tests**

Assert same seed yields identical scenario JSON and every adversarial scenario links to a stable safe control:

```dart
final first = const PrivacyAttackGenerator().generateCanonical(20260916);
final second = const PrivacyAttackGenerator().generateCanonical(20260916);
expect(first.map((e) => e.toJson()).toList(), second.map((e) => e.toJson()).toList());
expect(first.where((e) => e.adversarial).every((e) => e.sourceControlId.isNotEmpty), isTrue);
```

Add safe-control + attack pairs for wrong owner/recipient; VIEW/NOTIFY/BACKUP/EXPORT escalation; wrong category/field/purpose; before activation; exact expiry; exact revocation; post-revocation; before/at `dataFrom`; at/after `dataUntil`.

- [ ] **Step 2: Run focused test and verify RED**

Expected: generator/observer methods missing.

- [ ] **Step 3: Implement generic production observer**

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
      _ => throw ArgumentError('Unsupported target surface: ${scenario.targetSurface}'),
    };
  }
}
```

For generic requests, call both production evaluator and `PrivacySimulator`; normalize a deterministic validation failure if they disagree. Do not implement grant matching in simulation code.

- [ ] **Step 4: Implement A-D mutation templates**

Controls use positive contracts such as `allowAuthority`; mutations use `denyAuthority`. Keep fixed UTC timestamps and stable IDs. Only named dimensions may change between a control and its attack.

- [ ] **Step 5: Run Phase 11 focused tests plus Phase 9 regression**

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

### Task 3: Composed grants, relationship capability, visibility, and notification attacks E-H

**Files:**
- Modify: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- Observer target surfaces: `composedAccess`, `relationshipPermission`, `relationshipProjection`, `relationshipNotification`.
- Reuses `RelationshipAccessGate`, `RelationshipPermissionFirewall`, `RelationshipContextProjector`, `RelationshipNotificationPipeline`.

- [ ] **Step 1: Write failing E-H tests**

Cover generic grant recipient A + relationship grant recipient B; wrong relationship category; missing generic action; view/notify/playful/intimacy capability escalation; private/engineOnly/abstractShared raw exfiltration; fullyShared grant with more restrictive item; generic/categoryOnly/detailedWhenUnlocked notifications; locked detailed mode; missing playful/intimacy content capabilities; content capability without notify; wrong-recipient notification grant.

Positive controls must prove the authorized path works (`allowAuthority`, `allowProjection`, `allowRawExposure`, `emitNotification`) before the paired attack proves containment.

- [ ] **Step 2: Run focused test and verify RED**

Expected: unsupported target-surface failures.

- [ ] **Step 3: Implement E-G production adapters**

Map fixture payloads into real production types. Normalize only production outputs. For projections, record `projected`, `rawValueExposed`, and `effectiveVisibility`; never copy production `_mostRestrictive` logic.

- [ ] **Step 4: Implement H notification adapter**

Call production pipeline and classify output without serializing private message text:

```dart
return PrivacyAttackObservation(
  notificationEmitted: notification != null,
  notificationRedacted: notification?.redacted,
  stableReason: notification == null
      ? 'suppressed'
      : notification.redacted
          ? 'redacted'
          : 'detailed',
);
```

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

### Task 4: Revocation/key replay and relay binding attacks I-J

**Files:**
- Modify: `packages/simulation_domain/pubspec.yaml`
- Modify: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/test/privacy_attack_test.dart`
- Conditional only after a proven production defect: exact owning production source/test files under `packages/sharing/**` or `packages/crypto/**`.

**Interfaces:**
- Add direct dependency:

```yaml
  cycle_crypto:
    path: ../crypto
```

- Observer target surfaces: `revocationKeyState`, `relayTransport`.
- Reuses `PermissionEvaluator.revocationEffect`, `SharingRevocationCoordinator`, `RecipientKeyRegistry`, `AesGcmAuthenticatedCipher`, `SharingTransport`, `OpaqueRelayEnvelope`, `CiphertextEnvelope`.

- [ ] **Step 1: Write failing I-J tests**

Cover revoked grant after boundary; production revocation/key rotation result; prior key state revoked/version incremented; stale state not active; safe correct-recipient relay decrypt; wrong-recipient decrypt rejection; outer recipient/envelope-field tampering; authenticated ciphertext/associated-data tampering.

Assertions use stable booleans/reason categories only—never nonce or ciphertext equality.

- [ ] **Step 2: Run focused test and verify RED**

Expected: missing direct `cycle_crypto` dependency and unsupported target surfaces.

- [ ] **Step 3: Add direct crypto dependency and real AES-GCM fixture**

```dart
AesGcmAuthenticatedCipher _fixtureCipher() => AesGcmAuthenticatedCipher(
  keyResolver: (keyEnvelopeId) async =>
      List<int>.generate(32, (index) => (index + keyEnvelopeId.length) & 0xff),
);
```

Random AES-GCM nonce generation may occur internally, but envelope bytes never enter normalized evidence.

- [ ] **Step 4: Implement revocation/key adapter**

Use a local `RecipientKeyRegistry` plus a tiny adapter implementing `RecipientKeyRotator`, invoke `SharingRevocationCoordinator.revoke`, and call `PermissionEvaluator.revocationEffect` for production-exposed notification/export effects. Normalize only rotation/version/revoked-state/stop/invalidate booleans.

- [ ] **Step 5: Implement relay adapter**

Build a safe production `OpaqueRelayEnvelope` through `SharingTransport.encryptForRecipient`, apply the one named mutation, then call production `decryptForRecipient`/AES-GCM. Normalize `relayDecryptAccepted` or `relayIntegrityAccepted`; do not duplicate GCM or associated-data verification.

- [ ] **Step 6: Handle any discovered production defect correctly**

If a containment test reaches production and fails because production permits the attack, invoke `superpowers:systematic-debugging` before editing. Add a focused owning-package regression through the public production API, make the smallest production fix, run the owning package test suite, then rerun Phase 11. Never change the expected containment contract to make the test pass.

- [ ] **Step 7: Run I-J and relevant regressions**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart pub get && dart test test/privacy_attack_test.dart -r expanded'
```

If production files were changed, also run the exact owning package tests from the repo-root-mounted container.

- [ ] **Step 8: Commit Task 4**

Always stage only known Phase 11 files first:

```bash
git add packages/simulation_domain/pubspec.yaml packages/simulation_domain/lib/src/privacy_attack.dart packages/simulation_domain/test/privacy_attack_test.dart
```

If Step 6 changed production files, stage each exact changed production source/test path explicitly after reviewing `git status --short`; never stage an entire package directory. Remove generated untracked `packages/simulation_domain/pubspec.lock` unless it was already tracked. Then:

```bash
git commit -m "feat(simulation): attack revocation and relay privacy"
```

---

### Task 5: Canonical corpus, mandatory coverage, detector self-tests, and ordering

**Files:**
- Modify: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- `buildCanonicalPrivacyAttackScenarios(int seed) -> List<PrivacyAttackScenario>`
- Mandatory coverage: all 10 families; safe/adversarial; VIEW/NOTIFY/BACKUP/EXPORT; category/field/purpose; activation/expiry/revocation/data-window; relationship view/notify/relationshipIntelligence/playful/intimacy; private/engineOnly/abstractShared/fullyShared; generic/categoryOnly/detailedWhenUnlocked notification modes; key/revocation; relay recipient/integrity; Phase 8/9/10 reuse markers.

- [ ] **Step 1: Write failing coverage-gap and detector-category tests**

Delete one family from the corpus and expect S4 `coverage_gap`. Inject impossible observations to prove all stable S4 categories are reachable, including `stale_key_escape` and `relay_integrity_violation`.

- [ ] **Step 2: Run focused test and verify RED**

Expected: missing canonical coverage gate behavior.

- [ ] **Step 3: Build final risk-oriented safe-control/attack corpus**

Use fixed UTC times, stable IDs, explicit source-control links, single-axis mutations, and only named pairwise composition attacks. No full Cartesian expansion.

- [ ] **Step 4: Implement mandatory coverage gap labels**

Use deterministic sorted labels such as:

```dart
'family:${family.name}'
'action:view'
'scope:purpose'
'temporal:revocation'
'capability:intimacy'
'visibility:engineOnly'
'notification:detailedWhenUnlocked'
'surface:relayIntegrity'
'reuse:phase10'
```

Any missing mandatory label adds S4 `coverage_gap` evidence and makes the report fail.

- [ ] **Step 5: Prove canonical ordering**

Evaluate the same corpus in normal and reversed input order with the same seed and observer; assert byte-identical `toNormalizedJson()`.

- [ ] **Step 6: Run full `simulation_domain` tests**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart pub get && dart test'
```

Expected: PASS.

- [ ] **Step 7: Commit Task 5**

```bash
git add packages/simulation_domain/lib/src/privacy_attack.dart packages/simulation_domain/test/privacy_attack_test.dart
git commit -m "feat(simulation): add canonical privacy attack matrix"
```

---

### Task 6: Production smoke, docs, and Simulation Lab CI artifact

**Files:**
- Create: `packages/simulation_domain/bin/privacy_attack_smoke.dart`
- Create: `docs/SIMULATION_PRIVACY_ATTACK.md`
- Modify: `.github/workflows/simulation-lab.yml`
- Modify: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- `Future<PrivacyAttackReport> runProductionPrivacyAttackSmoke(int seed)`
- CLI: `dart run bin/privacy_attack_smoke.dart --seed=20260916`
- CI file: `privacy-attack-evidence.json`
- Exact artifact: `simulation-privacy-attack-evidence`

- [ ] **Step 1: Write failing production smoke determinism test**

```dart
final first = await runProductionPrivacyAttackSmoke(20260916);
final second = await runProductionPrivacyAttackSmoke(20260916);
expect(first.passed, isTrue);
expect(first.coverage.malformedInputFailures, 0);
expect(first.toNormalizedJson(), second.toNormalizedJson());
```

- [ ] **Step 2: Run focused test and verify RED**

Expected: smoke runner missing.

- [ ] **Step 3: Implement async smoke runner and CLI**

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

The smoke runner must build the canonical corpus, use `ProductionPrivacyAttackObserver`, and require mandatory coverage. No injected observer.

- [ ] **Step 4: Write `docs/SIMULATION_PRIVACY_ATTACK.md`**

Document purpose, production authority, A-J attack families, positive controls, minimal detector semantics, async relay/crypto handling, deterministic evidence rules, coverage gates, smoke/artifact, deferred Phase 16/21/22/general-fuzzing scope, and Issue #58 boundary.

- [ ] **Step 5: Extend `.github/workflows/simulation-lab.yml`**

Add `docs/SIMULATION_PRIVACY_ATTACK.md` to both PR and `main` push path filters. After Phase 10 smoke add:

```yaml
      - name: Privacy attack smoke
        run: dart run bin/privacy_attack_smoke.dart --seed=20260916 > privacy-attack-evidence.json
        working-directory: packages/simulation_domain
```

Add exact upload:

```yaml
      - name: Upload privacy attack evidence
        uses: actions/upload-artifact@v4
        with:
          name: simulation-privacy-attack-evidence
          path: packages/simulation_domain/privacy-attack-evidence.json
          if-no-files-found: error
          retention-days: 7
```

- [ ] **Step 6: Run fresh local verification**

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

Parse one output and assert `passed=true`, `syntheticEvidenceOnly=true`, zero malformed failures, all 10 families, safe/adversarial coverage, and every mandatory dimension.

- [ ] **Step 7: Run YAML/diff/hygiene checks**

Parse the workflow YAML, run `git diff --check`, scan changed files for real placeholder markers, verify no field-maintenance production path appears in the diff, and remove generated untracked lockfiles.

- [ ] **Step 8: Commit Task 6**

```bash
git add packages/simulation_domain/bin/privacy_attack_smoke.dart packages/simulation_domain/test/privacy_attack_test.dart docs/SIMULATION_PRIVACY_ATTACK.md .github/workflows/simulation-lab.yml
git commit -m "ci(simulation): publish privacy attack evidence"
```

---

### Task 7: Exact-SHA review, PR, CI/artifact verification, guarded merge, and Phase 11 closure

**Files:**
- No planned code changes after final verified feature tree.
- Update Issue #228 only after evidence gates pass.

**Interfaces:**
- Branch: `phase-11-privacy-attack-lab`
- Issue: #228
- Human blocker: #58 remains `open/reopened`
- Artifact: `simulation-privacy-attack-evidence`

- [ ] **Step 1: Read review/completion skills and perform focused review**

Read `superpowers:requesting-code-review` and `superpowers:verification-before-completion`. Review specifically for copied production policy, missing attack families, missing positive controls, leaked secret/crypto bytes, nondeterministic evidence, incomplete coverage gates, and any wording that could misrepresent synthetic evidence as human evidence.

- [ ] **Step 2: Run one final fresh local verification on the exact candidate tree**

Repeat Task 6 verification, run `git diff --check`, verify changed-file scope and clean status, record exact local test count, root tree SHA, and canonical evidence SHA-256.

- [ ] **Step 3: Publish byte-identical feature tree**

Use normal git push if authenticated; otherwise use GitHub Contents/Git Data. Verify every changed blob or final root tree matches the locally verified content. The remote branch HEAD becomes the canonical feature SHA.

- [ ] **Step 4: Open/update Phase 11 PR**

PR body includes #228, exact feature SHA/tree, test count, canonical evidence counts/hash, artifact name, review status, synthetic-evidence boundary, and #58 state.

- [ ] **Step 5: Require exact feature SHA CI success**

Repository CI and Simulation Lab for the exact feature SHA must both be `completed/success`.

- [ ] **Step 6: Download and independently verify feature artifact**

Require exact artifact name, feature head SHA binding, parseable canonical JSON, hash equal to local evidence, `passed=true`, `syntheticEvidenceOnly=true`, zero malformed failures, all attack families, and mandatory coverage.

- [ ] **Step 7: Re-fetch #58 and guarded-merge**

Immediately before merge, require #58 `open/reopened`, PR head still equal to verified feature SHA, expected base/main state, and no unresolved Critical/Important review blocker. Merge only after these invariants hold.

- [ ] **Step 8: Verify exact merge SHA/tree on `main`**

Require `main` equals returned merge SHA and merged content/tree contains the verified feature tree.

- [ ] **Step 9: Require exact merge SHA post-merge CI success**

For `event=push`, exact merge SHA repository CI and Simulation Lab must both be `completed/success`.

- [ ] **Step 10: Download and independently verify post-merge artifact**

Require artifact head SHA equals merge SHA and canonical evidence hash/counts remain valid.

- [ ] **Step 11: Update and close #228**

Only after all evidence is verified, mark acceptance criteria `[x]`, append feature SHA/tree, PR, merge SHA, workflow run IDs, artifact IDs/digests, canonical evidence SHA-256, local test count, and synthetic/human boundary. Close with state reason `completed`.

- [ ] **Step 12: Final invariants**

Re-fetch #228 (`closed/completed`), #58 (`open/reopened`), PR (`merged=true`), and `main` (exact merge SHA). Only then declare Phase 11 complete. Do not begin Phase 12 in the same completion turn.
