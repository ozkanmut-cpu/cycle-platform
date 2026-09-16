# Privacy Attack Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Phase 11 as a deterministic adversarial privacy-attack generator and containment-evidence harness that exercises Cycle's real production permission, sharing, relationship-privacy, notification, revocation, recipient-key, relay, and crypto primitives without duplicating production policy logic.

**Architecture:** Add one async Simulation Lab module, `privacy_attack.dart`, containing versioned models, deterministic safe-control/attack generation, production adapters, minimal containment contracts, mandatory coverage gates, and the canonical smoke corpus. Production engines decide authorization, visibility, redaction, revocation, key state, and relay/crypto behavior; Simulation Lab mutates inputs and checks normalized observable outcomes only. Relay/crypto execution is async from the first commit because production cipher/transport APIs return `Future`.

**Tech Stack:** Dart >=3.6, `test`, `cycle_permissions`, `cycle_sharing`, direct `cycle_crypto`, existing Simulation Lab canonical JSON conventions, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-16-privacy-attack-lab-design.md`

## Global Constraints

- Base is Phase 10 merge SHA `81e72ba4fb722dbcedd7d38835a483c3d98f0a9d`; all Phase 11 work stays on `phase-11-privacy-attack-lab` until guarded merge.
- Never modify `/opt/field-maintenance/app` or any field-maintenance production path. Cycle worktree activity is restricted to `/tmp/cycle-*`.
- Production packages remain authoritative. Simulation code must not reimplement grant matching, visibility ranking, notification rendering, key-rotation policy, recipient binding, or cryptographic verification.
- Every confirmed privacy-boundary breach is `InvariantSeverity.s4`.
- `PrivacyAttackObserver.observe` is `Future<PrivacyAttackObservation> observe(PrivacyAttackScenario scenario)` from Task 1 onward.
- Canonical evidence never serializes nonce, ciphertext, authentication tag, secret plaintext, key bytes, wall-clock time, host paths, environment values, process IDs, or stack traces.
- Production smoke uses `ProductionPrivacyAttackObserver` only. Injected observers exist only in detector self-tests.
- If an attack proves a production defect, stop that task, invoke `superpowers:systematic-debugging`, add a focused regression in the authoritative production package, fix production there, then rerun Phase 11. Never weaken the attack contract.
- Phase 16 wrong-patient safety, Phase 21 AI red-team breadth, Phase 22 Clinical + Playful collision breadth, general fuzzing, metamorphic testing, mutation testing, and human usability remain deferred.
- Issue #58 must remain `open/reopened`; Phase 11 evidence is synthetic only.
- Queued/pending/in-progress workflows are never green. Exact feature SHA and exact merge SHA must each reach `completed/success` for repository CI and Simulation Lab.

---

## File Structure

- Create `packages/simulation_domain/lib/src/privacy_attack.dart` — Phase 11 models, generator, production observer, detector, canonical corpus, coverage gates, smoke runner.
- Modify `packages/simulation_domain/lib/simulation_domain.dart` — export `privacy_attack.dart`.
- Modify `packages/simulation_domain/pubspec.yaml` — add direct `cycle_crypto` path dependency.
- Create `packages/simulation_domain/test/privacy_attack_test.dart` — Phase 11 tests.
- Create `packages/simulation_domain/bin/privacy_attack_smoke.dart` — async production-only smoke CLI.
- Create `docs/SIMULATION_PRIVACY_ATTACK.md` — architecture/evidence documentation.
- Modify `.github/workflows/simulation-lab.yml` — path trigger, smoke command, exact artifact upload.
- Modify production files only after a failing attack proves a production defect; then touch only exact owning source/test files.

---

### Task 1: Core async model, detector, report, and canonical serialization

**Files:**
- Create: `packages/simulation_domain/lib/src/privacy_attack.dart`
- Modify: `packages/simulation_domain/lib/simulation_domain.dart`
- Test: `packages/simulation_domain/test/privacy_attack_test.dart`

**Interfaces:**
- `privacyAttackSchemaVersion = 1`
- `PrivacyAttackFamily { identitySubstitution, actionEscalation, scopeSubstitution, temporalReplay, composedGrantConfusion, relationshipCapabilityEscalation, visibilityExfiltration, notificationLeakage, revocationAndKeyReplay, relayRecipientBinding }`
- `PrivacyContainmentContract { allowAuthority, denyAuthority, allowProjection, denyProjection, allowRawExposure, noRawExposure, emitNotification, redactOrSuppressNotification, requireKeyRotation, rejectStaleKey, allowRelayDecrypt, rejectRelayDecrypt, rejectRelayIntegrityTamper }`
- `PrivacyAttackMutation`, `PrivacyAttackScenario`, `PrivacyAttackObservation`, `PrivacyAttackResult`, `PrivacyAttackCoverage`, `PrivacyAttackReport`
- `PrivacyAttackScenario` contains required `sourceControlId`; safe controls set it to their own ID, attacks set it to the paired control ID.
- `PrivacyAttackResult` stores the normalized `PrivacyAttackObservation` used by the detector.
- `abstract class PrivacyAttackObserver { Future<PrivacyAttackObservation> observe(PrivacyAttackScenario scenario); }`
- `Future<PrivacyAttackReport> PrivacyAttackSuite.evaluate({required int seed, required Iterable<PrivacyAttackScenario> scenarios, required PrivacyAttackObserver observer, bool requireMandatoryCoverage = false})`

- [ ] **Step 1: Write failing model/round-trip/async detector tests**

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
  sourceControlId: 'control-view',
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

Add one injected observer returning `allowed:false` and one returning `allowed:true`; `denyAuthority` must pass the first and produce S4 `identity_scope_escape` for the second.

- [ ] **Step 2: Run focused test and verify RED**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart pub get && dart test test/privacy_attack_test.dart -r expanded'
```

Expected: compile failure because Phase 11 types do not exist.

- [ ] **Step 3: Implement validated models and async suite**

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

`PrivacyAttackObservation` has only stable nullable fields required by contracts: `allowed`, `projected`, `rawValueExposed`, `notificationEmitted`, `notificationRedacted`, `keyRotated`, `staleKeyActive`, `relayDecryptAccepted`, `relayIntegrityAccepted`, plus stable grant IDs/visibility/reason where production exposes them.

- [ ] **Step 4: Implement positive control and adversarial containment contracts**

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
PrivacyContainmentContract.rejectStaleKey => observation.staleKeyActive == false,
PrivacyContainmentContract.allowRelayDecrypt => observation.relayDecryptAccepted == true,
PrivacyContainmentContract.rejectRelayDecrypt => observation.relayDecryptAccepted == false,
PrivacyContainmentContract.rejectRelayIntegrityTamper =>
  observation.relayIntegrityAccepted == false,
```

- [ ] **Step 5: Implement stable finding categories and canonical JSON**

Use family + contract for categories that share a family:

```dart
if (scenario.family == PrivacyAttackFamily.revocationAndKeyReplay &&
    scenario.containmentContract == PrivacyContainmentContract.rejectStaleKey) {
  return 'stale_key_escape';
}
if (scenario.family == PrivacyAttackFamily.relayRecipientBinding &&
    scenario.containmentContract == PrivacyContainmentContract.rejectRelayIntegrityTamper) {
  return 'relay_integrity_violation';
}
```

Other family mappings are `identity_scope_escape`, `action_escalation`, `scope_escape`, `temporal_replay_escape`, `composed_gate_bypass`, `relationship_capability_escalation`, `visibility_exfiltration`, `notification_privacy_violation`, `revocation_escape`, and `relay_recipient_bypass`. Malformed input is `malformed_input`; missing coverage is `coverage_gap`. All breach results are S4. Sort maps/lists before `jsonEncode`; include `syntheticEvidenceOnly:true`.

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
- `const PrivacyAttackGenerator().generateCanonical(int seed) -> List<PrivacyAttackScenario>`
- `ProductionPrivacyAttackObserver` target surfaces `genericPermission`, `sharePolicy`
- Reuses `PermissionEvaluator`, `PrivacySimulator`, `SharePolicy`

- [ ] **Step 1: Write failing generator and A-D production tests**

```dart
final first = const PrivacyAttackGenerator().generateCanonical(20260916);
final second = const PrivacyAttackGenerator().generateCanonical(20260916);
expect(first.map((e) => e.toJson()).toList(), second.map((e) => e.toJson()).toList());
expect(first.where((e) => e.adversarial).every((e) => e.sourceControlId.isNotEmpty), isTrue);
```

Add paired controls/attacks for wrong owner/recipient; VIEW/NOTIFY/BACKUP/EXPORT escalation; wrong category/field/purpose; before activation; exact expiry; exact revocation; post-revocation; before/at `dataFrom`; at/after `dataUntil`.

- [ ] **Step 2: Run focused test and verify RED**

Expected: generator/production observer missing.

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

Cross-check generic decisions with production `PrivacySimulator`; a divergence becomes deterministic malformed/validation evidence. Do not match grants in simulation code.

- [ ] **Step 4: Implement deterministic A-D mutation templates**

Safe controls use `sourceControlId == id` and positive contracts such as `allowAuthority`; attacks point to that control and use `denyAuthority`. Preserve every unrelated fixture field.

- [ ] **Step 5: Run Phase 11 + Phase 9 regression tests**

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
- Target surfaces `composedAccess`, `relationshipPermission`, `relationshipProjection`, `relationshipNotification`
- Reuses `RelationshipAccessGate`, `RelationshipPermissionFirewall`, `RelationshipContextProjector`, `RelationshipNotificationPipeline`

- [ ] **Step 1: Write failing E-H tests**

Cover mixed-recipient generic/relationship grants; wrong relationship category; missing generic action; view/notify/playful/intimacy capability escalation; private/engineOnly/abstractShared raw exfiltration; fullyShared grant with a more restrictive item; generic/categoryOnly/detailedWhenUnlocked notifications; locked detailed mode; missing playful/intimacy content capabilities; capability without notify; wrong-recipient notification grant.

Each attack has a positive control proving the corresponding authorized path (`allowAuthority`, `allowProjection`, `allowRawExposure`, or `emitNotification`).

- [ ] **Step 2: Run focused test and verify RED**

Expected: unsupported target surfaces.

- [ ] **Step 3: Implement E-G production adapters**

Convert fixture payloads into real production types and normalize outputs. Projection observations record `projected`, `rawValueExposed`, and effective visibility. Never copy `_mostRestrictive` or grant-selection logic.

- [ ] **Step 4: Implement H notification adapter**

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

Do not serialize notification detail text.

- [ ] **Step 5: Add E-H deterministic templates and run Phase 9/10 regressions**

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
- Conditional after a proven production defect: exact owning files/tests under `packages/sharing/**` or `packages/crypto/**`

**Interfaces:**
- Add direct dependency `cycle_crypto: { path: ../crypto }`
- Target surfaces `revocationKeyState`, `relayTransport`
- Reuses `PermissionEvaluator.revocationEffect`, `SharingRevocationCoordinator`, `RecipientKeyRegistry`, `AesGcmAuthenticatedCipher`, `SharingTransport`, `OpaqueRelayEnvelope`, `CiphertextEnvelope`

- [ ] **Step 1: Write failing I-J tests**

Cover revoked grant after exact boundary; production revocation/key rotation; prior key state revoked/version incremented; stale key not active; safe correct-recipient relay decrypt; wrong-recipient decrypt rejection; outer recipient/envelope metadata tampering; ciphertext/associated-data tampering.

Assertions use stable booleans/reason categories only.

- [ ] **Step 2: Run focused test and verify RED**

Expected: direct `cycle_crypto` dependency and target surfaces missing.

- [ ] **Step 3: Add direct crypto dependency and real AES-GCM fixture**

Use all bytes of `keyEnvelopeId`, not only its length, so distinct envelope IDs cannot accidentally share fixture key material:

```dart
List<int> _fixtureKey(String keyEnvelopeId) {
  final source = utf8.encode(keyEnvelopeId);
  if (source.isEmpty) throw ArgumentError('keyEnvelopeId must not be blank');
  return List<int>.generate(
    32,
    (index) => (source[index % source.length] + (index * 31)) & 0xff,
  );
}

AesGcmAuthenticatedCipher _fixtureCipher() => AesGcmAuthenticatedCipher(
  keyResolver: (keyEnvelopeId) async => _fixtureKey(keyEnvelopeId),
);
```

AES-GCM nonce randomness is internal and never enters canonical evidence.

- [ ] **Step 4: Implement revocation/key adapter**

Use a local `RecipientKeyRegistry` and a tiny `RecipientKeyRotator` adapter, invoke `SharingRevocationCoordinator.revoke`, and call production `PermissionEvaluator.revocationEffect` for notification/export effects. Normalize `keyRotated`, versions/revoked state, `staleKeyActive`, notification stop, and export invalidation only.

Safe rotation controls use `requireKeyRotation`; stale-key adversarial scenarios use `rejectStaleKey`.

- [ ] **Step 5: Implement relay adapter**

Build safe envelopes using `SharingTransport.encryptForRecipient`; for controls use `allowRelayDecrypt`. Apply exactly one named recipient/integrity mutation and call production decrypt/AES-GCM; attacks use `rejectRelayDecrypt` or `rejectRelayIntegrityTamper`. Do not implement GCM or associated-data checks in simulation code.

- [ ] **Step 6: Handle a discovered production defect only in production**

If a production attack is not contained, invoke `superpowers:systematic-debugging` before edits. Add a focused regression through the owning production public API, apply the smallest production fix, run owning package tests, then rerun Phase 11. Do not alter expected containment.

- [ ] **Step 7: Run I-J tests and owning-package regressions if needed**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain ghcr.io/cirruslabs/flutter:stable sh -lc 'dart pub get && dart test test/privacy_attack_test.dart -r expanded'
```

- [ ] **Step 8: Commit Task 4**

Stage only known Phase 11 files:

```bash
git add packages/simulation_domain/pubspec.yaml packages/simulation_domain/lib/src/privacy_attack.dart packages/simulation_domain/test/privacy_attack_test.dart
```

If Step 6 changed production code, inspect `git status --short` and stage each exact changed production source/test path explicitly; never stage an entire package directory. Remove generated untracked `packages/simulation_domain/pubspec.lock` unless it was already tracked. Then:

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
- Coverage includes all 10 families; safe/adversarial; VIEW/NOTIFY/BACKUP/EXPORT; category/field/purpose; activation/expiry/revocation/data-window; relationship view/notify/relationshipIntelligence/playful/intimacy; private/engineOnly/abstractShared/fullyShared; generic/categoryOnly/detailedWhenUnlocked notification modes; key/revocation; relay recipient/integrity; Phase 8/9/10 reuse markers.

- [ ] **Step 1: Write failing coverage-gap and detector-category tests**

Delete one mandatory dimension/family and expect S4 `coverage_gap`. Inject impossible observations to prove every stable category is detectable, including `stale_key_escape` and `relay_integrity_violation`.

- [ ] **Step 2: Run focused test and verify RED**

Expected: canonical coverage gate missing.

- [ ] **Step 3: Build final risk-oriented corpus**

Use stable UTC times/IDs, positive controls, linked single-axis attacks, and only explicitly named pairwise composition attacks. No Cartesian expansion.

- [ ] **Step 4: Implement deterministic coverage gap labels**

Examples:

```dart
'family:${family.name}'
'action:view'
'scope:purpose'
'temporal:revocation'
'capability:intimacy'
'visibility:engineOnly'
'notification:detailedWhenUnlocked'
'surface:relayIntegrity'
'reuse:phase8'
'reuse:phase9'
'reuse:phase10'
```

Missing labels add S4 `coverage_gap` and fail the report.

- [ ] **Step 5: Prove canonical ordering**

Evaluate the corpus forward and reversed with the same seed/observer and assert byte-identical `toNormalizedJson()`.

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
- CLI `dart run bin/privacy_attack_smoke.dart --seed=20260916`
- CI file `privacy-attack-evidence.json`
- Exact artifact `simulation-privacy-attack-evidence`

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

The runner uses the canonical corpus, `ProductionPrivacyAttackObserver`, and mandatory coverage only.

- [ ] **Step 4: Write `docs/SIMULATION_PRIVACY_ATTACK.md`**

Document production authority, A-J attack families, positive controls, detector limits, async relay/crypto handling, determinism, coverage, smoke/artifact, deferred scope, and #58 boundary.

- [ ] **Step 5: Extend `.github/workflows/simulation-lab.yml`**

Add `docs/SIMULATION_PRIVACY_ATTACK.md` to both PR and `main` path filters, then after Phase 10 smoke:

```yaml
      - name: Privacy attack smoke
        run: dart run bin/privacy_attack_smoke.dart --seed=20260916 > privacy-attack-evidence.json
        working-directory: packages/simulation_domain
```

Upload:

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

Parse workflow YAML, run `git diff --check`, scan changed files for real placeholder markers, verify no field-maintenance production path appears in the diff, and remove generated untracked lockfiles.

- [ ] **Step 8: Commit Task 6**

```bash
git add packages/simulation_domain/bin/privacy_attack_smoke.dart packages/simulation_domain/test/privacy_attack_test.dart docs/SIMULATION_PRIVACY_ATTACK.md .github/workflows/simulation-lab.yml
git commit -m "ci(simulation): publish privacy attack evidence"
```

---

### Task 7: Exact-SHA review, PR, CI/artifact verification, guarded merge, and closure

**Files:**
- No planned code changes after the final verified feature tree.
- Update Issue #228 only after evidence gates pass.

**Interfaces:**
- Branch `phase-11-privacy-attack-lab`
- Issue #228
- #58 remains `open/reopened`
- Artifact `simulation-privacy-attack-evidence`

- [ ] **Step 1: Read review/completion skills and perform focused review**

Read `superpowers:requesting-code-review` and `superpowers:verification-before-completion`. Review for copied production policy, missing positive controls/families, secret/crypto bytes in evidence, nondeterminism, incomplete coverage, and synthetic-vs-human evidence mistakes.

- [ ] **Step 2: Run one final fresh local verification on the exact candidate tree**

Repeat Task 6 verification, run `git diff --check`, verify changed-file scope and clean status, record exact test count, root tree SHA, and canonical evidence SHA-256.

- [ ] **Step 3: Publish byte-identical feature tree**

Use authenticated git push if available; otherwise GitHub Contents/Git Data. Verify changed blobs or final root tree are byte-identical to local verification. Treat remote branch HEAD as canonical feature SHA.

- [ ] **Step 4: Open/update Phase 11 PR**

Include #228, exact feature SHA/tree, test count, evidence counts/hash, artifact name, review status, synthetic-evidence boundary, and #58 state.

- [ ] **Step 5: Require exact feature SHA CI success**

Repository CI and Simulation Lab for that exact feature SHA both reach `completed/success`.

- [ ] **Step 6: Download and independently verify feature artifact**

Require exact artifact name/head SHA, parseable canonical JSON, hash equal to local evidence, `passed=true`, `syntheticEvidenceOnly=true`, zero malformed failures, all families, mandatory coverage.

- [ ] **Step 7: Re-fetch #58 and guarded-merge**

Immediately before merge require #58 `open/reopened`, PR head still the verified feature SHA, expected base/main state, and no unresolved Critical/Important blocker.

- [ ] **Step 8: Verify exact merge SHA/tree on `main`**

Require `main` equals returned merge SHA and merged content/tree contains the verified feature tree.

- [ ] **Step 9: Require exact merge SHA post-merge CI success**

For `event=push`, repository CI and Simulation Lab on the exact merge SHA both reach `completed/success`.

- [ ] **Step 10: Download and independently verify post-merge artifact**

Require artifact head SHA equals merge SHA and canonical evidence hash/counts remain valid.

- [ ] **Step 11: Update and close #228**

Only after all gates pass, mark acceptance criteria `[x]`, append feature SHA/tree, PR, merge SHA, workflow run IDs, artifact IDs/digests, canonical evidence SHA-256, local test count, and synthetic/human boundary. Close `completed`.

- [ ] **Step 12: Final invariants**

Re-fetch #228 (`closed/completed`), #58 (`open/reopened`), PR (`merged=true`), and `main` (exact merge SHA). Only then declare Phase 11 complete. Do not begin Phase 12 in the same completion turn.
