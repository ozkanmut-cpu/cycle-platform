# Phase 9 Permissions & Information-Flow Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic Phase 9 permission/information-flow scenario lab that invokes Cycle production permission/sharing engines, fails S4 on authorization or visibility breaches, and publishes canonical CI evidence.

**Architecture:** `packages/simulation_domain/lib/src/permission_flow.dart` owns only scenario generation, production-engine adaptation, normalized observations, contract evaluation, deterministic coverage, and canonical serialization. `cycle_permissions` and `cycle_sharing` remain authoritative; Phase 9 never reimplements their policy logic. The canonical smoke runs production adapters only and emits `simulation-permission-flow-evidence`.

**Tech Stack:** Dart 3.x, package:test, existing `cycle_permissions` and `cycle_sharing` packages, GitHub Actions Simulation Lab workflow, Flutter stable Docker verification.

**Spec:** `docs/superpowers/specs/2026-09-16-permission-information-flow-lab-design.md`

## Global Constraints

- Tracking issue is #224; Issue #58 must remain `open/reopened` throughout.
- Production-domain permission and sharing engines are authoritative.
- Every Phase 9 information-flow contract violation is S4 and fails the report.
- Production smoke uses no injected/fake observer.
- All timestamps are UTC; wall-clock time is never an input.
- Same validated inputs + seed must produce byte-identical normalized JSON.
- Phase 10/11/16/21/22 breadth is explicitly out of scope.
- Do not touch `/opt/field-maintenance/app`.

---
## File Structure

- Create `packages/simulation_domain/lib/src/permission_flow.dart`: Phase 9 public models, production observer, suite, canonical matrix, coverage, serialization.
- Create `packages/simulation_domain/test/permission_flow_test.dart`: RED/GREEN tests for models, production boundaries, detector breaches, determinism, malformed input, smoke coverage.
- Create `packages/simulation_domain/bin/permission_flow_smoke.dart`: fixed-seed production-only CLI evidence.
- Modify `packages/simulation_domain/lib/simulation_domain.dart`: export Phase 9 API.
- Create `docs/SIMULATION_PERMISSION_FLOW.md`: evidence/coverage/operator contract.
- Modify `.github/workflows/simulation-lab.yml`: path trigger, smoke step, artifact upload.

### Task 1: Core models, validation, and canonical report

**Files:**
- Create: `packages/simulation_domain/lib/src/permission_flow.dart`
- Create: `packages/simulation_domain/test/permission_flow_test.dart`

**Interfaces:**
- Produces: `PermissionFlowScenarioKind`, `PermissionFlowExpectation`, `PermissionFlowScenario`, `PermissionFlowObservation`, `PermissionFlowResult`, `PermissionFlowCoverage`, `PermissionFlowReport`, `PermissionFlowValidationException`.
- `PermissionFlowScenario` carries stable id/schema/seed/UTC time, owner/recipient, kind, expectation, violation reason, structured payload and coverage metadata only; no duplicated policy decision.

- [ ] **Step 1: Write failing model tests**

```dart
test('scenario rejects blank id, non-UTC time, and unsupported schema', () {
  expect(() => PermissionFlowScenario(id: '', schemaVersion: 1, seed: 7,
    at: DateTime.utc(2026, 9, 16), ownerId: 'p1', recipientId: 'r1',
    kind: PermissionFlowScenarioKind.generic,
    expectation: PermissionFlowExpectation.mustDeny,
    violationReason: 'default_deny_bypass', payload: const {}), throwsA(isA<PermissionFlowValidationException>()));
});
```
- [ ] **Step 2: Run the focused test and verify RED**

Run:
```bash
cd packages/simulation_domain
dart test test/permission_flow_test.dart -n 'scenario rejects blank id, non-UTC time, and unsupported schema'
```
Expected: compile failure because Phase 9 types do not exist yet.

- [ ] **Step 3: Implement minimal validated models and canonical JSON**

```dart
enum PermissionFlowScenarioKind { generic, sharePolicy, relationship, composedAccess, projection }
enum PermissionFlowExpectation { mustAllow, mustDeny, mustProjectWithoutRaw, mustProject, mustProjectWithRaw }

class PermissionFlowValidationException implements Exception {
  const PermissionFlowValidationException(this.message);
  final String message;
}
```

`PermissionFlowScenario` validates schema version `1`, nonblank ids/actor scope, and `at.isUtc`. `PermissionFlowReport.toNormalizedJson()` recursively sorts map keys and serializes results in stable scenario-id order. `fromJson` rejects unsupported enum/schema values rather than defaulting them.

- [ ] **Step 4: Add result/report round-trip and S4 tests, then GREEN**

```dart
expect(result.severity, 's4');
expect(PermissionFlowReport.fromJson(report.toJson()).toNormalizedJson(), report.toNormalizedJson());
```

Run `dart test test/permission_flow_test.dart`; expected PASS for Task 1 tests.

- [ ] **Step 5: Commit**

```bash
git add packages/simulation_domain/lib/src/permission_flow.dart packages/simulation_domain/test/permission_flow_test.dart
git commit -m 'feat(simulation): add permission flow core model'
```
### Task 2: Production observer for generic, share, relationship, composed, and projection flows

**Files:**
- Modify: `packages/simulation_domain/lib/src/permission_flow.dart`
- Modify: `packages/simulation_domain/test/permission_flow_test.dart`

**Interfaces:**
- Produces: abstract `PermissionFlowObserver` with `PermissionFlowObservation observe(PermissionFlowScenario scenario)`.
- Produces: `ProductionPermissionFlowObserver` that maps scenario payloads into real `PermissionGrant`, `PermissionRequest`, `RelationshipCategoryGrant`, `RelationshipAccessRequest`, and `RelationshipContextItem` objects.
- Uses: `PermissionEvaluator`, `PrivacySimulator`, `SharePolicy`, `RelationshipPermissionFirewall`, `RelationshipAccessGate`, `RelationshipContextProjector`.

- [ ] **Step 1: Write RED tests against real generic permission behavior**

```dart
test('production observer keeps action escalation fail closed', () {
  final scenario = PermissionFlowScenario(id: 'generic.action.view-to-notify', schemaVersion: 1,
    seed: 20260916, at: DateTime.utc(2026, 9, 16, 9), ownerId: 'patient-1',
    recipientId: 'partner-1', kind: PermissionFlowScenarioKind.generic,
    expectation: PermissionFlowExpectation.mustDeny, violationReason: 'action_escalation',
    action: 'notify', escalationAttempt: true, payload: {
      'request': {'action': 'notify', 'category': 'cycle'},
      'grants': [{'id': 'grant-view', 'ownerId': 'patient-1', 'recipientId': 'partner-1',
        'recipientKind': 'partner', 'actions': ['view'], 'scope': {'categories': ['cycle']},
        'createdAt': '2026-09-16T08:00:00.000Z', 'version': 1}],
    });
  expect(ProductionPermissionFlowObserver().observe(scenario).allowed, isFalse);
});
```

Include explicit fixtures for wrong owner, wrong recipient, unrelated grant, VIEW→NOTIFY/BACKUP/EXPORT, category mismatch, field mismatch, purpose mismatch, pre-activation, exact valid-until, exact revoked-at, before/after data window, and inclusive data boundaries.

- [ ] **Step 2: Run focused tests and verify RED**

Run `dart test test/permission_flow_test.dart -n 'production observer keeps action, actor, scope, and time boundaries fail closed'`.
Expected: compile failure because production observer/helpers are absent.

- [ ] **Step 3: Implement generic/share production adapters only**

The generic branch must call `PermissionEvaluator.evaluate`; the batch/privacy branch must call `PrivacySimulator.simulate`; the share-policy branch must call `SharePolicy.evaluate`. Payload parsing may translate enum names and timestamps, but must not decide authorization itself.
- [ ] **Step 4: Write RED tests for relationship/composed/projection behavior**

In the test file, define `buildComposedViewFixturesForTest()` and `buildProjectionFixturesForTest()` as test-local factories that construct three explicit `PermissionFlowScenario` values each using the same payload schema consumed by `ProductionPermissionFlowObserver`; they contain no authorization logic, only fixture data. Then add:

```dart
test('composed access requires generic and relationship gates', () {
  final scenarios = buildComposedViewFixturesForTest();
  final observer = ProductionPermissionFlowObserver();
  expect(observer.observe(scenarios['genericOnly']!).allowed, isFalse);
  expect(observer.observe(scenarios['relationshipOnly']!).allowed, isFalse);
  expect(observer.observe(scenarios['both']!).allowed, isTrue);
});

test('visibility ceiling prevents raw leakage', () {
  final scenarios = buildProjectionFixturesForTest();
  final observer = ProductionPermissionFlowObserver();
  expect(observer.observe(scenarios['engineOnly']!).exposesRawValue, isFalse);
  expect(observer.observe(scenarios['abstractShared']!).exposesRawValue, isFalse);
  expect(observer.observe(scenarios['fullyShared']!).exposesRawValue, isTrue);
});
```

- [ ] **Step 5: Verify RED, then implement relationship branches**

`relationship` invokes `RelationshipPermissionFirewall.evaluate`; `composedAccess` invokes `RelationshipAccessGate.evaluate`; `projection` invokes `RelationshipContextProjector.project`. Preserve production reason/matched-grant/visibility observations. Invalid composed capability pairs are surfaced as deterministic validation errors.

- [ ] **Step 6: Run Task 2 tests GREEN and commit**

```bash
dart test test/permission_flow_test.dart
git add packages/simulation_domain/lib/src/permission_flow.dart packages/simulation_domain/test/permission_flow_test.dart
git commit -m 'feat(simulation): adapt production permission flows'
```

### Task 3: S4 contract evaluator, detector self-tests, and fail-closed malformed handling

**Files:**
- Modify: `packages/simulation_domain/lib/src/permission_flow.dart`
- Modify: `packages/simulation_domain/test/permission_flow_test.dart`

**Interfaces:**
- Produces: `PermissionFlowSuite({PermissionFlowObserver observer = const ProductionPermissionFlowObserver()})`.
- Produces: `PermissionFlowResult evaluate(PermissionFlowScenario scenario)` and `PermissionFlowReport run(...)`.
- [ ] **Step 1: Write detector RED tests with injected impossible observations**

```dart
class UnsafeObserver implements PermissionFlowObserver {
  const UnsafeObserver(this.observation);
  final PermissionFlowObservation observation;
  @override
  PermissionFlowObservation observe(PermissionFlowScenario scenario) => observation;
}

test('mustDeny breach becomes S4 with scenario violation reason', () {
  final scenario = PermissionFlowScenario(id: 'detector.action-escalation', schemaVersion: 1,
    seed: 20260916, at: DateTime.utc(2026, 9, 16), ownerId: 'patient-1',
    recipientId: 'partner-1', kind: PermissionFlowScenarioKind.generic,
    expectation: PermissionFlowExpectation.mustDeny, violationReason: 'action_escalation',
    action: 'notify', escalationAttempt: true, payload: const {});
  final result = PermissionFlowSuite(observer: const UnsafeObserver(
    PermissionFlowObservation(allowed: true))).evaluate(scenario);
  expect(result.passed, isFalse);
  expect(result.severity, 's4');
  expect(result.reasonCode, 'action_escalation');
});
```

Add equivalent impossible raw-leak observations for `private_data_exposed`, `engine_only_data_exposed`, and `abstract_data_exposed`.

- [ ] **Step 2: Verify RED**

Run `dart test test/permission_flow_test.dart -n 'mustDeny breach becomes S4 with scenario violation reason'`.
Expected: compile failure because the suite evaluator is absent.

- [ ] **Step 3: Implement expectation-only contract evaluation**

`mustAllow` passes only when `observation.allowed`; `mustDeny` passes only when not allowed; `mustProjectWithoutRaw` passes only for a present projection with `exposesRawValue == false`; `mustProject` requires a projection but permits stricter redaction; `mustProjectWithRaw` is reserved for contracts that explicitly require raw exposure. The suite never recalculates production permission rules.

Preserve exact scenario violation reason codes in failures: `actor_scope_escape`, `default_deny_bypass`, `action_escalation`, `category_scope_escape`, `field_scope_escape`, `purpose_scope_escape`, `grant_time_escape`, `revocation_breach`, `data_window_escape`, `relationship_capability_escalation`, `composed_gate_bypass`, `private_data_exposed`, `engine_only_data_exposed`, and `abstract_data_exposed`.

- [ ] **Step 4: Add malformed-input RED tests and fail-closed handling**

```dart
expect(() => PermissionFlowScenario.fromJson({...validScenarioJson, 'schemaVersion': 99}),
  throwsA(isA<PermissionFlowValidationException>()));
```

Observer payload parse/production-constructor errors are converted to deterministic `malformed_input` S4 results by `run`; they increment `malformedInputFailures` and are never skipped.
- [ ] **Step 5: Run Task 3 tests GREEN and commit**

```bash
dart test test/permission_flow_test.dart
git add packages/simulation_domain/lib/src/permission_flow.dart packages/simulation_domain/test/permission_flow_test.dart
git commit -m 'feat(simulation): enforce permission flow contracts'
```

### Task 4: Canonical risk-oriented matrix, coverage, and production smoke

**Files:**
- Modify: `packages/simulation_domain/lib/src/permission_flow.dart`
- Modify: `packages/simulation_domain/test/permission_flow_test.dart`
- Create: `packages/simulation_domain/bin/permission_flow_smoke.dart`

**Interfaces:**
- Produces: `List<PermissionFlowScenario> buildCanonicalPermissionFlowScenarios(int seed)`.
- Produces: `PermissionFlowReport runProductionPermissionFlowSmoke(int seed)`.
- Coverage exposes `scenarioKinds`, `actions`, `relationshipCapabilities`, `visibilities`, `boundaries`, `escalationAttempts`, and `leakageAttempts`.

- [ ] **Step 1: Write RED coverage/determinism tests**

```dart
test('canonical production smoke is deterministic and covers every contract family', () {
  final a = runProductionPermissionFlowSmoke(20260916);
  final b = runProductionPermissionFlowSmoke(20260916);
  expect(a.passed, isTrue);
  expect(a.toNormalizedJson(), b.toNormalizedJson());
  expect(a.coverage.actions.keys, containsAll(['view', 'notify', 'backup', 'export']));
  expect(a.coverage.relationshipCapabilities.keys,
    containsAll(['view', 'notify', 'relationshipIntelligence', 'playful', 'intimacy']));
  expect(a.coverage.visibilities.keys,
    containsAll(['private', 'engineOnly', 'abstractShared', 'fullyShared']));
  expect(a.coverage.boundaries.keys,
    containsAll(['grantStart', 'grantEnd', 'revocation', 'dataFrom', 'dataUntil']));
  expect(a.coverage.escalationAttempts, greaterThan(0));
  expect(a.coverage.leakageAttempts, greaterThan(0));
});
```
- [ ] **Step 2: Verify RED**

Run `dart test test/permission_flow_test.dart -n 'canonical production smoke is deterministic and covers every contract family'`.
Expected: compile failure because canonical scenario builder/smoke do not exist.

- [ ] **Step 3: Implement the canonical matrix**

The fixed matrix must include safe controls plus adversarial cases for: actor isolation/default deny; all four generic actions with cross-action escalation; category/field/purpose containment; grant start/end/revocation; dataFrom/dataUntil inclusive controls and out-of-window denials; `SharePolicy` independence; all five relationship capabilities; composed VIEW and NOTIFY with both/single gates; private/engine-only/abstract/full projection visibility.

Use deterministic IDs such as `generic.action.view-to-notify`, `generic.revocation.exact`, `composed.view.generic-only`, and `projection.abstract.raw-ceiling`. Seed may select stable fixture values/order only through deterministic helpers; wall-clock state is forbidden.

- [ ] **Step 4: Implement CLI and verify byte stability**

```dart
void main(List<String> args) {
  final seedArg = args.where((item) => item.startsWith('--seed=')).firstOrNull;
  final seed = int.tryParse(seedArg?.substring('--seed='.length) ?? '') ?? 20260916;
  final report = runProductionPermissionFlowSmoke(seed);
  if (!report.passed) throw StateError('Permission-flow production smoke contains S4 failures');
  print(report.toNormalizedJson());
}
```

Run twice and compare:
```bash
dart run bin/permission_flow_smoke.dart --seed=20260916 > /tmp/pf-a.json
dart run bin/permission_flow_smoke.dart --seed=20260916 > /tmp/pf-b.json
cmp /tmp/pf-a.json /tmp/pf-b.json
```

- [ ] **Step 5: Run full package tests GREEN and commit**

```bash
dart test
git add packages/simulation_domain/lib/src/permission_flow.dart packages/simulation_domain/test/permission_flow_test.dart packages/simulation_domain/bin/permission_flow_smoke.dart
git commit -m 'feat(simulation): add canonical permission flow smoke'
```
### Task 5: Public export, documentation, and Simulation Lab CI artifact

**Files:**
- Modify: `packages/simulation_domain/lib/simulation_domain.dart`
- Create: `docs/SIMULATION_PERMISSION_FLOW.md`
- Modify: `.github/workflows/simulation-lab.yml`

**Interfaces:**
- Public package export: `export 'src/permission_flow.dart';`
- Workflow smoke output: `packages/simulation_domain/permission-flow-evidence.json`.
- Artifact name: exactly `simulation-permission-flow-evidence`.

- [ ] **Step 1: Write RED public-export test**

Add an import-only API test in `permission_flow_test.dart` that constructs `PermissionFlowScenario` from `package:cycle_simulation_domain/simulation_domain.dart`; remove any direct `src/` import. Run the focused test and verify it fails until the public export exists.

- [ ] **Step 2: Export the API and GREEN**

```dart
export 'src/permission_flow.dart';
```

Run `dart test test/permission_flow_test.dart`; expected PASS.

- [ ] **Step 3: Write Phase 9 operator/developer documentation**

Document authoritative engines, matrix strategy, contract/reason codes, action/purpose/time/visibility semantics, canonical evidence, production-only smoke rule, deferred Phase 10/11/16/21/22 scope, and explicit Issue #58 human-evidence boundary.

- [ ] **Step 4: Extend Simulation Lab workflow**

Add `docs/SIMULATION_PERMISSION_FLOW.md` to pull-request and main path filters. Add after Hard Safety smoke:

```yaml
      - name: Permission and information-flow smoke
        run: dart run bin/permission_flow_smoke.dart --seed=20260916 > permission-flow-evidence.json
        working-directory: packages/simulation_domain
```
Add upload:

```yaml
      - name: Upload permission and information-flow evidence
        uses: actions/upload-artifact@v4
        with:
          name: simulation-permission-flow-evidence
          path: packages/simulation_domain/permission-flow-evidence.json
          if-no-files-found: error
          retention-days: 7
```

- [ ] **Step 5: Format/test workflow-adjacent changes and commit**

```bash
dart format --output=none --set-exit-if-changed lib test bin
dart analyze .
dart test
git add packages/simulation_domain/lib/simulation_domain.dart docs/SIMULATION_PERMISSION_FLOW.md .github/workflows/simulation-lab.yml
git commit -m 'ci(simulation): publish permission flow evidence'
```

### Task 6: Fresh verification, branch review, GitHub completion gate

**Files:**
- Modify only if verification reveals a Phase 9 defect.
- Update: Issue #224 acceptance checklist after evidence exists.

- [ ] **Step 1: Run fresh local verification in Flutter stable Docker**

```bash
docker run --rm -v "$PWD":/workspace -w /workspace/packages/simulation_domain \
  ghcr.io/cirruslabs/flutter:stable bash -lc \
  'set -e; dart pub get; dart format --output=none --set-exit-if-changed lib test bin; dart analyze .; dart test; dart run bin/permission_flow_smoke.dart --seed=20260916 > /tmp/pf1.json; dart run bin/permission_flow_smoke.dart --seed=20260916 > /tmp/pf2.json; cmp /tmp/pf1.json /tmp/pf2.json'
```

Remove generated `packages/simulation_domain/pubspec.lock` if untracked verification residue.
- [ ] **Step 2: Review exact Phase 9 diff**

Compare branch base `e248f1b099d140b0c3fd1e0ee2a0c699f7a679ce` through feature HEAD. Confirm only the approved spec/plan, Phase 9 simulation code/tests/docs/export/workflow changed; no unrelated files.

- [ ] **Step 3: Push branch and require exact feature-head workflows**

Push `phase-9-permission-information-flow-lab`. Create a PR to `main` that tracks #224 and explicitly states synthetic evidence does not satisfy #58. Continue only after both repository CI and Simulation Lab on the exact feature HEAD report real `completed/success`; queued/in-progress is never called green.

- [ ] **Step 4: Verify feature-head artifact**

On the successful Simulation Lab run, require non-expired artifact named exactly `simulation-permission-flow-evidence` whose workflow head SHA equals the feature HEAD.

- [ ] **Step 5: Re-fetch Issue #58 before merge**

Require `state=open` and `state_reason=reopened`. If accidentally closed, reopen it before any Phase 9 completion action.

- [ ] **Step 6: Merge PR, then require exact merge-SHA workflows**

Merge only after feature-head evidence is complete. Fetch the resulting `main` SHA and require both repository CI and Simulation Lab on that exact merge SHA to report `completed/success`.

- [ ] **Step 7: Verify post-merge artifact and close #224**

Require `simulation-permission-flow-evidence` on the successful merge-SHA Simulation Lab run. Update all #224 acceptance checkboxes to `[x]`, close #224 with `state_reason=completed`, and fetch it again to verify.

- [ ] **Step 8: Final #58 and main verification**

Re-fetch #58 and require open/reopened. Fetch `main` and confirm it equals the verified merge SHA. Only then report `Phase 9 [x] COMPLETE`. Do not start Phase 10 in this phase.
