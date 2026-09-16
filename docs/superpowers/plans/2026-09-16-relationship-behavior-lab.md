# Phase 10 Relationship Behavior Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic Simulation Lab Relationship Behavior Lab that exercises the production relationship stack across signals, situation, memory/context, novelty, partner home, notifications, Playful behavior, intimacy, and presets while reusing Phase 8/9 safety and permission contracts.

**Architecture:** Follow the existing `permission_flow.dart` / `hard_safety.dart` pattern: versioned scenario/result/report models plus a narrow production observer, generic expected-observation matching, deterministic canonical fixtures, detector self-tests, and a production-only smoke command. Production engines remain authoritative; Simulation Lab only constructs deterministic production inputs, records stable observations, compares those observations with scenario-declared expected facts, and computes machine-readable coverage.

**Tech Stack:** Dart >=3.6.0, package:test, existing `cycle_sharing`, `cycle_permissions`, and `cycle_clinical_copilot` package APIs, GitHub Actions `Simulation Lab` workflow.

**Spec:** `docs/superpowers/specs/2026-09-16-relationship-behavior-lab-design.md`

## Global Constraints

- Work only on branch `phase-10-relationship-behavior-lab` from the verified Phase 9 merge lineage.
- Do not touch `/opt/field-maintenance/app` or any field-maintenance production application files.
- Issue #58 must remain `open/reopened`; Phase 10 synthetic evidence never counts as human usability evidence.
- Reuse Phase 8 hard-safety and Phase 9 permission/information-flow semantics; do not create parallel authorization, visibility, consent, novelty-ranking, notification-redaction, or clinical-truth policy.
- Defer Phase 11 Privacy Attack Lab, Phase 16 Wrong-Patient Safety, Phase 21 AI Red-Team expansion, and Phase 22 Clinical + Playful Collision breadth.
- Use deterministic UTC instants, stable IDs, stable ordering, canonical JSON, no wall-clock timestamps, no random UUIDs, and no host-specific paths.
- The exact CI artifact name is `simulation-relationship-behavior-evidence`.
- A queued or in-progress workflow never counts as green; completion requires `completed/success` on the exact SHA being verified.
- Every implementation task follows RED → GREEN → REFACTOR and ends in a focused commit.

---

### Task 1: Core relationship-behavior model, validation, report, and generic detector

**Files:**
- Create: `packages/simulation_domain/lib/src/relationship_behavior.dart`
- Modify: `packages/simulation_domain/lib/simulation_domain.dart`
- Create/Test: `packages/simulation_domain/test/relationship_behavior_test.dart`

**Interfaces:**
- Produces `relationshipBehaviorSchemaVersion = 1`.
- Produces `RelationshipBehaviorScenarioFamily` with `signalProjection`, `situation`, `memoryContext`, `novelty`, `partnerHome`, `notification`, `playful`, `intimacy`, `preset`.
- Produces `RelationshipBehaviorScenario`, `RelationshipBehaviorObservation`, `RelationshipBehaviorObserver`, `RelationshipBehaviorResult`, `RelationshipBehaviorCoverage`, `RelationshipBehaviorReport`, and `RelationshipBehaviorSuite`.
- `RelationshipBehaviorScenario.expectedFacts` is a canonical map of observable facts that must be present with equal values in the production observation; this is data-driven contract checking, not a second policy engine.

- [ ] **Step 1: Write failing core-model tests**

Add tests that require blank IDs, owner==recipient, non-UTC `at`, unsupported schema versions, blank expected-fact keys, and seed mismatch to fail closed. Add a report round-trip test that proves stable ordering and normalized JSON.

```dart
final scenario = RelationshipBehaviorScenario(
  id: 'signal.safe.explicit',
  schemaVersion: relationshipBehaviorSchemaVersion,
  seed: 20260916,
  at: DateTime.utc(2026, 9, 16, 9),
  ownerId: 'patient-1',
  recipientId: 'partner-1',
  family: RelationshipBehaviorScenarioFamily.signalProjection,
  expectedFacts: const <String, Object?>{'selectedSignalId': 'signal-explicit'},
  riskTags: const <String>{'precedence'},
  safeControl: true,
);
expect(RelationshipBehaviorScenario.fromJson(scenario.toJson()).toJson(), scenario.toJson());
```

- [ ] **Step 2: Run the targeted test and confirm RED**

Run:

```bash
cd packages/simulation_domain
dart test test/relationship_behavior_test.dart -r expanded
```

Expected: compile failure because Phase 10 types are not yet defined.

- [ ] **Step 3: Implement the minimal model and canonical serialization**

Use these public shapes:

```dart
const int relationshipBehaviorSchemaVersion = 1;

enum RelationshipBehaviorScenarioFamily {
  signalProjection,
  situation,
  memoryContext,
  novelty,
  partnerHome,
  notification,
  playful,
  intimacy,
  preset,
}

class RelationshipBehaviorScenario {
  RelationshipBehaviorScenario({
    required this.id,
    required this.schemaVersion,
    required this.seed,
    required this.at,
    required this.ownerId,
    required this.recipientId,
    required this.family,
    required Map<String, Object?> expectedFacts,
    required Set<String> riskTags,
    Map<String, Object?> payload = const <String, Object?>{},
    this.safeControl = false,
    this.adversarial = false,
  });
  // immutable fields, toJson/fromJson, strict validation
}

class RelationshipBehaviorObservation {
  RelationshipBehaviorObservation({Map<String, Object?> facts = const {}});
  final Map<String, Object?> facts;
  Map<String, Object?> toJson();
}

abstract class RelationshipBehaviorObserver {
  const RelationshipBehaviorObserver();
  RelationshipBehaviorObservation observe(RelationshipBehaviorScenario scenario);
}
```

`RelationshipBehaviorSuite.evaluate` must compare the canonicalized `expectedFacts` as a recursive subset of `observation.facts`. A missing key or unequal value yields `passed=false` and stable `reasonCode='contract_mismatch'`; observer exceptions become `reasonCode='malformed_input'` in `run`.

`RelationshipBehaviorResult.severity` is S4 when `riskTags` contain one of `scope`, `permission`, `visibility`, `notificationPrivacy`, `consent`, or `clinicalTruth`; otherwise use the lowest existing invariant severity that still preserves pass/fail reporting. Do not change the existing `InvariantSeverity` enum.

- [ ] **Step 4: Export and run GREEN**

Add:

```dart
export 'src/relationship_behavior.dart';
```

to `lib/simulation_domain.dart`, then run:

```bash
dart format lib/src/relationship_behavior.dart lib/simulation_domain.dart test/relationship_behavior_test.dart
dart test test/relationship_behavior_test.dart -r expanded
```

Expected: core-model tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/simulation_domain/lib/src/relationship_behavior.dart \
  packages/simulation_domain/lib/simulation_domain.dart \
  packages/simulation_domain/test/relationship_behavior_test.dart
git commit -m "feat(simulation): add relationship behavior core model"
```

---

### Task 2: Production observer for signals, situation, memory/context, novelty, and Partner Home

**Files:**
- Modify: `packages/simulation_domain/lib/src/relationship_behavior.dart`
- Test: `packages/simulation_domain/test/relationship_behavior_test.dart`

**Interfaces:**
- Produces `ProductionRelationshipBehaviorObserver extends RelationshipBehaviorObserver`.
- Consumes production `RelationshipSignalEngine`, `PartnerSignalProjector`, `RelationshipSituationEngine`, `CoupleMemoryEngine`, `CoupleContextEngine`, `NoveltyEngine`, `RelationshipHomeOrchestrator`, and `PartnerExperienceCoordinator`.
- Production observations use stable primitive facts only: IDs, enum `.name`, booleans, nullable raw values, ordered lists, and counts.

- [ ] **Step 1: Add RED tests for contract families A–E**

Create fixture helpers that build real `RelationshipCategoryGrant`, `RelationshipSignal`, `RoomSignal`, `CoupleMemoryItem`, `CoupleContextEntry<Object?>`, `CoupleDna`, `NoveltyCandidate`, and `PartnerExperienceInput` objects through scenario payload conversion. Assert at least these production facts:

```dart
expect(observer.observe(explicitWins).facts['selectedSignalId'], 'signal-explicit');
expect(observer.observe(expiredSignal).facts['projectedSignalIds'], isEmpty);
expect(observer.observe(needsSpace).facts['roomAction'], 'giveSpace');
expect(observer.observe(lowValueMoment).facts['microMomentSurfaced'], false);
expect(observer.observe(engineOnlyMemory).facts['memoryRawValues'], <Object?>[null]);
expect(observer.observe(noNoveltyFallback).facts['suggestionIds'], isEmpty);
expect(observer.observe(wrongPartnerHome).facts['homeBuildFailedClosed'], true);
```

Include input-permutation tests proving observation ordering is identical.

- [ ] **Step 2: Run targeted tests and confirm RED**

```bash
dart test test/relationship_behavior_test.dart --name "production observer A-E" -r expanded
```

Expected: failures because production observer family handlers are absent.

- [ ] **Step 3: Implement production family handlers**

Construct `ProductionRelationshipBehaviorObserver` with production engines as constructor dependencies and switch only on `scenario.family`:

```dart
class ProductionRelationshipBehaviorObserver extends RelationshipBehaviorObserver {
  const ProductionRelationshipBehaviorObserver({
    this.signalEngine = const RelationshipSignalEngine(),
    this.signalProjector = const PartnerSignalProjector(),
    this.situationEngine = const RelationshipSituationEngine(),
    this.memoryEngine = const CoupleMemoryEngine(),
    this.contextEngine = const CoupleContextEngine(),
    this.noveltyEngine = const NoveltyEngine(),
    this.homeOrchestrator = const RelationshipHomeOrchestrator(),
    this.partnerCoordinator = const PartnerExperienceCoordinator(),
  });

  @override
  RelationshipBehaviorObservation observe(RelationshipBehaviorScenario scenario) =>
      switch (scenario.family) {
        RelationshipBehaviorScenarioFamily.signalProjection => _observeSignalProjection(scenario),
        RelationshipBehaviorScenarioFamily.situation => _observeSituation(scenario),
        RelationshipBehaviorScenarioFamily.memoryContext => _observeMemoryContext(scenario),
        RelationshipBehaviorScenarioFamily.novelty => _observeNovelty(scenario),
        RelationshipBehaviorScenarioFamily.partnerHome => _observePartnerHome(scenario),
        _ => _observeRemainingFamily(scenario),
      };
}
```

For each handler, build production objects from payload, call the production engine, and expose observation facts. Do not reproduce internal comparator/ranking/visibility calculations. Examples of stable facts:

```dart
{
  'selectedSignalId': selected?.id,
  'projectedSignalIds': projected.map((e) => e.id).toList(),
  'roomAction': room?.action.name,
  'weather': weather.kind.name,
  'microMomentSurfaced': micro.shouldSurface,
  'microMomentId': micro.candidate?.id,
  'memoryIds': manual.entries.map((e) => e.id).toList(),
  'memoryRawValues': manual.entries.map((e) => e.value).toList(),
  'suggestionIds': suggestions.map((e) => e.candidateId).toList(),
  'homeCardIds': home.cards.map((e) => e.id).toList(),
  'homeRawValues': home.cards.map((e) => e.rawValue).toList(),
}
```

Wrong-partner `PartnerExperienceCoordinator.build` exceptions are captured by the observer as a stable `homeBuildFailedClosed=true` fact only for the explicit wrong-scope scenario path; all unrelated unexpected exceptions still bubble to `RelationshipBehaviorSuite.run` as malformed input.

- [ ] **Step 4: Run GREEN and regression tests**

```bash
dart format lib/src/relationship_behavior.dart test/relationship_behavior_test.dart
dart test test/relationship_behavior_test.dart -r expanded
dart test
```

Expected: all current package tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/simulation_domain/lib/src/relationship_behavior.dart \
  packages/simulation_domain/test/relationship_behavior_test.dart
git commit -m "feat(simulation): observe production relationship surfaces"
```

---

### Task 3: Production observer for notifications, Playful, intimacy, and presets with Phase 8/9 reuse

**Files:**
- Modify: `packages/simulation_domain/lib/src/relationship_behavior.dart`
- Test: `packages/simulation_domain/test/relationship_behavior_test.dart`

**Interfaces:**
- Adds remaining family handlers using `RelationshipNotificationPipeline`, `PlayfulEngine`, `IntimacyEngine`, and `RelationshipPresetExpander`.
- Reuses `HardSafetySuite`/`HardSafetyInvariantId.relationshipClinicalTruthPreserved` for the Phase 8 truth-preservation cross-check.
- Reuses `PermissionFlowSuite` or the same production permission primitives for Phase 9 visibility/capability evidence; no copied permission decision function is permitted.

- [ ] **Step 1: Add RED tests for contract families F–I**

Required assertions include:

```dart
expect(observer.observe(genericNotification).facts['notificationRedacted'], true);
expect(observer.observe(lockedDetailed).facts['notificationBody'], 'You have a private partner update.');
expect(observer.observe(missingIntimacyNotification).facts['notificationPresented'], false);
expect(observer.observe(playfulTruth).facts['truthFirst'], true);
expect(observer.observe(playfulTruth).facts['phase8TruthGatePassed'], true);
expect(observer.observe(preferenceOnlyIntimacy).facts['intimacyDecisionKinds'], isEmpty);
expect(observer.observe(twoYes).facts['intimacyDecisionKinds'], <String>['mutuallyWilling']);
expect(observer.observe(hardBoundary).facts['intimacyDecisionKinds'], isEmpty);
expect(observer.observe(customPreset).facts['presetGrantIds'], isEmpty);
```

Also cover `no`, `notTonight`, `askFirst`, `maybe`, cooldown, both-direction intimacy permission, spicy-without-intimacy denial, and deterministic preset category ordering.

- [ ] **Step 2: Run targeted tests and confirm RED**

```bash
dart test test/relationship_behavior_test.dart --name "production observer F-I" -r expanded
```

Expected: failures because the remaining observer handlers are absent.

- [ ] **Step 3: Implement notification/Playful/intimacy/preset handlers**

Notification observations must expose only output from `RelationshipNotificationPipeline.present`:

```dart
{
  'notificationPresented': notification != null,
  'notificationRedacted': notification?.redacted,
  'notificationTitle': notification?.title,
  'notificationBody': notification?.body,
}
```

Playful observations must expose layer order/text/tone and invoke the existing Phase 8 invariant as a cross-check using a `HardSafetyCase` built from the same truth text/severity. Record `phase8TruthGatePassed` from the Phase 8 result; do not recalculate clinical-truth safety independently.

Intimacy observations must expose production `IntimacyDecision.id`, `.kind.name`, `createdAt`, and `expiresAt` only. Never derive consent from preferences/willingness in Simulation Lab.

Preset observations must call both `RelationshipPresetExpander.expand` and `grantsFromPreset`, record sorted category/capability/visibility maps and generated grant IDs, then verify an explicit downstream `RelationshipPermissionFirewall.evaluate` scenario when the canonical fixture declares a policy-check payload.

- [ ] **Step 4: Run GREEN plus Phase 8/9 regression coverage**

```bash
dart format lib/src/relationship_behavior.dart test/relationship_behavior_test.dart
dart test test/relationship_behavior_test.dart -r expanded
dart test test/hard_safety_test.dart test/permission_flow_test.dart -r expanded
dart test
```

Expected: all tests pass; Phase 8/9 tests remain unchanged and green.

- [ ] **Step 5: Commit**

```bash
git add packages/simulation_domain/lib/src/relationship_behavior.dart \
  packages/simulation_domain/test/relationship_behavior_test.dart
git commit -m "feat(simulation): cover relationship privacy and consent behavior"
```

---

### Task 4: Canonical risk-oriented matrix, coverage gates, and detector self-tests

**Files:**
- Modify: `packages/simulation_domain/lib/src/relationship_behavior.dart`
- Test: `packages/simulation_domain/test/relationship_behavior_test.dart`

**Interfaces:**
- Produces `buildCanonicalRelationshipBehaviorScenarios(int seed)`.
- Produces `runProductionRelationshipBehaviorSmoke(int seed)`.
- Coverage must include every family plus tag counters for `scope`, `lifecycle`, `permission`, `visibility`, `notificationPrivacy`, `consent`, `ordering`, `suppression`, `noFallback`, `clinicalTruth`, `phase8Reuse`, and `phase9Reuse`.

- [ ] **Step 1: Add RED canonical-matrix and detector tests**

Require all nine families and mandatory dimensions:

```dart
final report = runProductionRelationshipBehaviorSmoke(20260916);
expect(report.passed, isTrue);
expect(report.coverage.families.keys, containsAll(RelationshipBehaviorScenarioFamily.values.map((e) => e.name)));
for (final tag in <String>[
  'scope', 'lifecycle', 'permission', 'visibility', 'notificationPrivacy',
  'consent', 'ordering', 'suppression', 'noFallback', 'clinicalTruth',
  'phase8Reuse', 'phase9Reuse',
]) {
  expect(report.coverage.riskTags[tag], greaterThan(0), reason: tag);
}
```

Add same-seed byte equality and unique scenario-ID assertions. Add `_UnsafeRelationshipBehaviorObserver` self-tests that intentionally return an unexpected raw value, presented notification, invented novelty suggestion, mutual intimacy decision, or corrupted truth fact and prove generic expected-fact matching fails with the canonical scenario reason/severity metadata.

- [ ] **Step 2: Run canonical tests and confirm RED**

```bash
dart test test/relationship_behavior_test.dart --name "canonical relationship behavior" -r expanded
```

Expected: failures because canonical scenarios/coverage are incomplete.

- [ ] **Step 3: Build the smallest complete deterministic scenario matrix**

Use the fixed UTC base instant:

```dart
final at = DateTime.utc(2026, 9, 16, 9);
```

Include at minimum these named scenario groups with stable IDs:

```text
signal.safe.explicit-over-derived
signal.lifecycle.revoked-exact
signal.scope.wrong-recipient
situation.safe.needs-space
situation.order.priority-recency
situation.suppression.zero-log
memory.visibility.engine-only
memory.visibility.abstract
memory.scope.wrong-partner
novelty.filter.do-not-suggest
novelty.filter.cooldown
novelty.no-fallback
home.safe.authorized-surfaces
home.scope.wrong-partner
home.visibility.engine-only
notification.generic.redacted
notification.category.redacted
notification.locked.redacted
notification.permission.notify-only
notification.permission.playful-missing
notification.permission.intimacy-missing
playful.safe.truth-first
playful.permission.missing
playful.spicy.intimacy-missing
intimacy.preference-not-consent
intimacy.mutual-yes
intimacy.no
intimacy.not-tonight
intimacy.ask-first
intimacy.maybe
intimacy.hard-boundary
intimacy.cooldown
intimacy.permission.one-direction-missing
preset.minimal
preset.support
preset.close-partner
preset.full-transparency
preset.custom-empty
```

Add extra ordering/malformed/Phase 8/Phase 9 reuse scenarios only where needed to fill mandatory coverage. Do not chase an arbitrary scenario count.

`RelationshipBehaviorCoverage` must be computed from scenario metadata + results and expose configured/evaluated/passed/failed/malformed/safe/adversarial counts, family counts, risk-tag counts, and explicit `phase8ReuseCount` / `phase9ReuseCount`.

The smoke report fails when any mandatory family/tag is absent even if all evaluated scenarios individually pass. Represent that as a synthetic coverage result/reason `coverage_gap`, not as a silent boolean.

- [ ] **Step 4: Run GREEN and determinism checks**

```bash
dart format lib/src/relationship_behavior.dart test/relationship_behavior_test.dart
dart test test/relationship_behavior_test.dart -r expanded
for i in 1 2; do dart test test/relationship_behavior_test.dart --name "same seed is byte stable"; done
```

Expected: all relationship behavior tests pass deterministically.

- [ ] **Step 5: Commit**

```bash
git add packages/simulation_domain/lib/src/relationship_behavior.dart \
  packages/simulation_domain/test/relationship_behavior_test.dart
git commit -m "feat(simulation): add canonical relationship behavior matrix"
```

---

### Task 5: Production-only smoke executable and canonical evidence file

**Files:**
- Create: `packages/simulation_domain/bin/relationship_behavior_smoke.dart`
- Test: `packages/simulation_domain/test/relationship_behavior_test.dart`

**Interfaces:**
- CLI: `dart run bin/relationship_behavior_smoke.dart --seed=20260916`
- Stdout: exactly one normalized JSON report plus trailing newline.
- Exit: non-zero by throwing `StateError` when `report.passed` is false.

- [ ] **Step 1: Add RED smoke-equivalence test**

Add a test that calls `runProductionRelationshipBehaviorSmoke(20260916)` twice and validates normalized equality, `syntheticEvidenceOnly == true`, all mandatory coverage present, and zero malformed failures.

- [ ] **Step 2: Run test and confirm RED for missing executable/evidence contract**

```bash
dart test test/relationship_behavior_test.dart --name "production smoke evidence" -r expanded
```

- [ ] **Step 3: Create the smoke CLI**

```dart
import 'package:cycle_simulation_domain/simulation_domain.dart';

void main(List<String> args) {
  final seedArg = args.where((item) => item.startsWith('--seed=')).firstOrNull;
  final seed = int.tryParse(seedArg?.substring('--seed='.length) ?? '') ?? 20260916;
  final report = runProductionRelationshipBehaviorSmoke(seed);
  if (!report.passed) {
    throw StateError('Relationship-behavior production smoke contains contract failures');
  }
  print(report.toNormalizedJson());
}
```

- [ ] **Step 4: Verify byte stability outside the test runner**

```bash
dart format bin/relationship_behavior_smoke.dart
dart run bin/relationship_behavior_smoke.dart --seed=20260916 > /tmp/relationship-behavior-1.json
dart run bin/relationship_behavior_smoke.dart --seed=20260916 > /tmp/relationship-behavior-2.json
cmp /tmp/relationship-behavior-1.json /tmp/relationship-behavior-2.json
python3 -m json.tool /tmp/relationship-behavior-1.json >/dev/null
```

Expected: `cmp` exit 0 and valid JSON.

- [ ] **Step 5: Commit**

```bash
git add packages/simulation_domain/bin/relationship_behavior_smoke.dart \
  packages/simulation_domain/test/relationship_behavior_test.dart
git commit -m "feat(simulation): add relationship behavior smoke evidence"
```

---

### Task 6: Documentation and Simulation Lab CI artifact

**Files:**
- Create: `docs/SIMULATION_RELATIONSHIP_BEHAVIOR.md`
- Modify: `.github/workflows/simulation-lab.yml`
- Test/Verify: workflow YAML parse and local smoke.

**Interfaces:**
- Workflow smoke output: `packages/simulation_domain/relationship-behavior-evidence.json`.
- Artifact: exact `simulation-relationship-behavior-evidence`.

- [ ] **Step 1: Add the documentation path trigger and smoke/upload steps**

Add `docs/SIMULATION_RELATIONSHIP_BEHAVIOR.md` under both `pull_request.paths` and `push.paths`.

After the permission-flow smoke step add:

```yaml
      - name: Relationship behavior smoke
        run: dart run bin/relationship_behavior_smoke.dart --seed=20260916 > relationship-behavior-evidence.json
        working-directory: packages/simulation_domain
```

After the permission-flow artifact upload add:

```yaml
      - name: Upload relationship behavior evidence
        uses: actions/upload-artifact@v4
        with:
          name: simulation-relationship-behavior-evidence
          path: packages/simulation_domain/relationship-behavior-evidence.json
          if-no-files-found: error
          retention-days: 7
```

- [ ] **Step 2: Write architecture/evidence documentation**

`docs/SIMULATION_RELATIONSHIP_BEHAVIOR.md` must document:

1. Phase 10 purpose and production-authority rule.
2. Contract families A–I.
3. Data-driven expected-fact detector strategy.
4. Canonical deterministic matrix and risk-tag coverage.
5. Phase 8 hard-safety reuse and Phase 9 permission-flow reuse.
6. Exact smoke command and artifact name.
7. Deferred Phase 11/16/21/22 scope.
8. Explicit statement that evidence is synthetic and does not satisfy Issue #58.

- [ ] **Step 3: Verify YAML and full package checks locally**

```bash
python3 - <<'PY'
import yaml
with open('.github/workflows/simulation-lab.yml', encoding='utf-8') as f:
    yaml.safe_load(f)
print('yaml-ok')
PY
cd packages/simulation_domain
dart format --output=none --set-exit-if-changed lib test bin
dart analyze .
dart test
dart run bin/relationship_behavior_smoke.dart --seed=20260916 > /tmp/relationship-behavior-final.json
```

Expected: YAML parse success; analyzer has no errors/warnings; all tests pass; smoke exits 0.

- [ ] **Step 4: Run repository hygiene checks**

From repo root:

```bash
git diff --check main...HEAD
! git diff --unified=0 main...HEAD | grep -E '^\+.*\b(TBD|FIXME|TODO:)\b'
! git diff --name-only main...HEAD | grep -E '^/opt/field-maintenance/app|field-maintenance-platform'
git status --short
```

Expected: no whitespace errors, no true placeholders, no forbidden files, clean worktree after removing generated `pubspec.lock` if untracked.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/simulation-lab.yml docs/SIMULATION_RELATIONSHIP_BEHAVIOR.md
git commit -m "ci(simulation): publish relationship behavior evidence"
```

---

### Task 7: Exact-SHA verification, review, PR, merge, post-merge evidence, and Issue #226 completion

**Files:**
- No planned source changes. Any code-review defect must go through a new RED/GREEN focused commit before continuing.

**Interfaces:**
- Feature branch exact HEAD is the sole pre-merge evidence key.
- Merge SHA is the sole post-merge evidence key.
- Issue #226 is closed only after post-merge checks and artifact inspection.
- Issue #58 remains open/reopened throughout.

- [ ] **Step 1: Verify local final state and #58 before publishing**

Require clean worktree, record `git rev-parse HEAD`, run all Task 6 local verification commands, and fetch Issue #58 from GitHub. Abort completion if #58 is not `open/reopened`.

- [ ] **Step 2: Publish branch and open PR**

Push the branch without force. Open a PR titled `Phase 10: relationship behavior lab` with `Tracks #226`, summary, local verification evidence, and a prominent statement that synthetic evidence does not satisfy #58.

- [ ] **Step 3: Request and complete code review**

Review every changed file against the spec. Verify there is no copied production policy logic and no accidental expansion into Phase 11/16/21/22. Any important finding returns to TDD before continuing.

- [ ] **Step 4: Verify exact feature-head workflows and artifact**

For the exact feature SHA, require both repository CI and Simulation Lab workflow runs to reach `completed/success`. Download artifact `simulation-relationship-behavior-evidence`; verify its workflow head SHA equals the exact feature SHA, it is non-expired, JSON parses, `passed=true`, all nine families and mandatory risk tags have positive coverage, malformed failures are zero, and a repeated local smoke JSON is byte-identical or canonically identical according to the implemented normalized form.

- [ ] **Step 5: Merge with exact-head protection**

Immediately before merge, re-fetch #58 and PR metadata. Require #58 `open/reopened`, PR mergeable, and PR head SHA equal to the verified feature SHA. Merge using the exact expected head SHA guard.

- [ ] **Step 6: Verify exact merge-SHA workflows and artifact**

Fetch `main` and record the real merge SHA. Require repository CI and Simulation Lab push workflows on that exact merge SHA to reach `completed/success`. Download the post-merge `simulation-relationship-behavior-evidence` artifact and repeat the head-SHA, non-expired, JSON, pass, coverage, malformed, and deterministic evidence checks.

- [ ] **Step 7: Complete Issue #226 only after evidence exists**

Update all Issue #226 acceptance criteria to `[x]` and append completion evidence containing PR number, feature SHA, feature CI/Simulation run numbers, merge SHA, post-merge CI/Simulation run numbers, artifact name/id, canonical JSON SHA-256, configured/evaluated/passed/failed/malformed counts, and final #58 state. Close #226 with `state_reason=completed`.

- [ ] **Step 8: Final Phase 10 closure gate**

Re-fetch `main`, #226, and #58. Report `Phase 10 [x] COMPLETE` only when:

```text
main == verified merge SHA
#226 == closed/completed with every acceptance checkbox [x]
#58 == open/reopened
feature exact SHA: CI completed/success + Simulation Lab completed/success
merge exact SHA: CI completed/success + Simulation Lab completed/success
post-merge artifact verified and non-expired
```

Do not begin Phase 11 in the same Phase 10 closure turn.
