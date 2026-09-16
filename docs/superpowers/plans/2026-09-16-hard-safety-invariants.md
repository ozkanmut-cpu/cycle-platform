# Phase 8 Hard Safety Invariants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic cross-domain Hard Safety Suite that invokes production safety engines, emits S4 release-gate evidence, and publishes seeded CI artifacts without duplicating business policy.

**Architecture:** `simulation_domain` owns normalized hard-safety cases/results/reports and thin adapters around `permissions`, `sharing`, `clinical_copilot`, and the Phase 7 oracle. Production adapters are the default for smoke/CI; evaluator self-tests may inject normalized observations only to prove fail-closed detector behavior.

**Tech Stack:** Dart 3.x, package:test, existing Cycle domain packages, GitHub Actions Simulation Lab workflow.

**Spec:** `docs/superpowers/specs/2026-09-16-hard-safety-invariants-design.md`

## Global Constraints
- Every Phase 8 gate is S4; no violation can degrade to a soft score.
- Production-domain engines remain authoritative; Simulation Lab does not copy permission, sharing, AI, review, or uncertainty business logic.
- CI smoke uses production adapters only; injected observations are test-only detector checks.
- All timestamps are UTC and no wall clock participates in evaluation.
- Same validated inputs + seed must produce byte-stable canonical JSON.
- Issue #58 remains open; synthetic evidence is not human usability evidence.

---

### Task 1: Package wiring and core report model

**Files:**
- Modify: `packages/simulation_domain/pubspec.yaml`
- Modify: `packages/simulation_domain/lib/cycle_simulation_domain.dart`
- Create: `packages/simulation_domain/lib/src/hard_safety.dart`
- Test: `packages/simulation_domain/test/hard_safety_test.dart`

**Interfaces:**
- Produces `HardSafetyInvariantId`, `HardSafetyCase`, `HardSafetyObservation`, `HardSafetyResult`, `HardSafetyCoverage`, `HardSafetyReport`, and `HardSafetySuite`.
- `HardSafetyResult.severity` is always `InvariantSeverity.s4`.
- `HardSafetyReport.toNormalizedJson()` returns deterministic canonical JSON.

- [ ] **Step 1: Write failing model tests** for blank IDs, non-UTC timestamps, deterministic ordering, all-S4 results, report pass/fail counts, JSON round-trip, and same-seed byte equality.
- [ ] **Step 2: Run `dart test test/hard_safety_test.dart`** and verify RED because the hard-safety API does not exist.
- [ ] **Step 3: Add production package dependencies** `cycle_permissions`, `cycle_sharing`, and `cycle_clinical_copilot` as local path dependencies.
- [ ] **Step 4: Implement minimal validated models and canonical serialization** in `hard_safety.dart`; reject unknown invariant IDs and non-UTC timestamps with `ArgumentError`.
- [ ] **Step 5: Export the API** from `cycle_simulation_domain.dart`.
- [ ] **Step 6: Run the focused test** and verify GREEN.

### Task 2: Uncertainty and permission production adapters

**Files:**
- Modify: `packages/simulation_domain/lib/src/hard_safety.dart`
- Test: `packages/simulation_domain/test/hard_safety_test.dart`

**Interfaces:**
- Produces `UncertaintyHardSafetyAdapter` backed by `GroundTruthOracle`.
- Produces `PermissionHardSafetyAdapter` backed by `PermissionEvaluator`.
- Evaluator reason codes are stable strings: `ok`, `missing_collapsed`, `conflict_collapsed`, `estimate_collapsed`, `revocation_breach`.

- [ ] **Step 1: Add failing tests** proving missing→known/zero, conflicting→known, and estimated→known become S4 failures while correct preservation passes.
- [ ] **Step 2: Run focused tests and verify RED** on missing adapter/evaluator behavior.
- [ ] **Step 3: Implement the uncertainty adapter** by invoking Phase 7 oracle semantics and mapping oracle findings into normalized observations.
- [ ] **Step 4: Verify GREEN** for uncertainty tests.
- [ ] **Step 5: Add failing tests** for permission access one second before revocation (pass) and at/after revocation (production denial = safe), plus an injected `allowed: true` boundary observation that must fail S4.
- [ ] **Step 6: Run and verify RED**, then implement the permission adapter using real `PermissionGrant`, `PermissionRequest`, and `PermissionEvaluator`.
- [ ] **Step 7: Run focused tests and verify GREEN**.

### Task 3: AI and doctor-review hard gates

**Files:**
- Modify: `packages/simulation_domain/lib/src/hard_safety.dart`
- Test: `packages/simulation_domain/test/hard_safety_test.dart`

**Interfaces:**
- Produces `AiContextHardSafetyAdapter`, `AiEvidenceHardSafetyAdapter`, `AiActionHardSafetyAdapter`, and `DoctorReviewHardSafetyAdapter`.
- Stable failure reason codes: `context_crossed_firewall`, `evidence_accepted`, `autonomous_action_accepted`, `review_gate_bypassed`.

- [ ] **Step 1: Add failing context-firewall tests** that verify blocked/disallowed context causes production orchestration to fail before model invocation, and an injected crossed-firewall observation fails S4.
- [ ] **Step 2: Verify RED**, implement adapter via `AiOrchestrator`, then verify GREEN.
- [ ] **Step 3: Add failing evidence tests** for missing evidence and unknown evidence references plus an injected accepted-unsupported-evidence observation.
- [ ] **Step 4: Verify RED**, implement adapter via `AiEvidenceValidator`, then verify GREEN.
- [ ] **Step 5: Add failing autonomous-action tests** for diagnose, prescribe, changeTreatment, and clinicalWrite plus injected acceptance.
- [ ] **Step 6: Verify RED**, implement adapter via `AiSafetyValidator`, then verify GREEN.
- [ ] **Step 7: Add failing doctor-review tests** for absent, mismatched, rejected, and approved review records plus injected unapproved commit capability.
- [ ] **Step 8: Verify RED**, implement adapter via `DoctorReviewGate`, then verify GREEN.

### Task 4: Clinical-truth preservation through Playful Engine

**Files:**
- Modify: `packages/simulation_domain/lib/src/hard_safety.dart`
- Test: `packages/simulation_domain/test/hard_safety_test.dart`

**Interfaces:**
- Produces `ClinicalTruthHardSafetyAdapter` backed by `PlayfulEngine`.
- Normalized observation records first-layer kind/text/tone and whether truth exists.
- Stable failure reason code: `clinical_truth_corrupted`.

- [ ] **Step 1: Add failing tests** proving informational, review-recommended, and urgent clinical truth remains first, verbatim, and `PlayfulTone.plain` even when playful output is disabled/disallowed.
- [ ] **Step 2: Add injected detector tests** for omitted, rewritten, reordered, and non-plain truth observations; each must fail S4.
- [ ] **Step 3: Run focused tests and verify RED**.
- [ ] **Step 4: Implement production adapter and evaluator** using real `PlayfulEngine` compositions; do not reproduce permission logic.
- [ ] **Step 5: Run focused tests and verify GREEN**.

### Task 5: Seeded production smoke, malformed fail-closed coverage, docs, and CI artifact

**Files:**
- Create: `packages/simulation_domain/bin/hard_safety_smoke.dart`
- Create: `docs/SIMULATION_HARD_SAFETY.md`
- Modify: `.github/workflows/simulation-lab.yml`
- Test: `packages/simulation_domain/test/hard_safety_test.dart`

**Interfaces:**
- `hard_safety_smoke.dart --seed=<int>` emits one canonical JSON report using production adapters only.
- Smoke covers every initial invariant ID and exits non-zero if the production report fails.
- Workflow uploads artifact named exactly `simulation-hard-safety-evidence`.

- [ ] **Step 1: Add failing tests** for malformed case payloads and unsupported IDs to fail closed deterministically.
- [ ] **Step 2: Verify RED**, implement validation/fail-closed report behavior, then verify GREEN.
- [ ] **Step 3: Implement the seeded smoke command** with fixed deterministic UTC fixtures and production adapters only.
- [ ] **Step 4: Run smoke twice with the same seed** and byte-compare outputs; outputs must be identical and report `syntheticEvidenceOnly: true`.
- [ ] **Step 5: Write `SIMULATION_HARD_SAFETY.md`** covering S4 semantics, production-adapter authority, injected-test boundary, deferred phases, and Issue #58 boundary.
- [ ] **Step 6: Update `simulation-lab.yml`** to run the smoke command and upload `simulation-hard-safety-evidence` alongside existing simulation artifacts.
- [ ] **Step 7: Run `dart format --output=none --set-exit-if-changed lib test bin`, `dart analyze .`, `dart test`, and the smoke command** in the Flutter stable Docker image; all must succeed.

### Task 6: GitHub integration and completion gate

**Files:**
- Review all Phase 8 changed files only.

**Interfaces:**
- Feature branch `issue-221-hard-safety-invariants` targets `main`.
- Issue #221 remains open until post-merge CI and Simulation Lab are successful.
- Issue #58 remains open throughout.

- [ ] **Step 1: Commit implementation to the feature branch** with no unrelated files.
- [ ] **Step 2: Open PR for #221** and verify exact feature HEAD.
- [ ] **Step 3: Require feature-head CI and Simulation Lab `completed/success`**; if a workflow fails, diagnose only the first real failure, fix it, and repeat exact-head verification.
- [ ] **Step 4: Verify `simulation-hard-safety-evidence` artifact** exists on the successful feature-head Simulation Lab run.
- [ ] **Step 5: Merge the PR only after exact-head workflows are successful**.
- [ ] **Step 6: Immediately re-fetch #58 and reopen it if GitHub closed it indirectly**.
- [ ] **Step 7: Require main merge-SHA CI and Simulation Lab `completed/success`**, and verify the post-merge hard-safety artifact.
- [ ] **Step 8: Check all #221 acceptance boxes, close #221 as completed, and re-fetch #58 to prove it remains open.**
