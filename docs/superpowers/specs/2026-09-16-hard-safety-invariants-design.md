# Phase 8 Hard Safety Invariants — Design

Date: 2026-09-16
Issue: #221
Status: Approved architecture; implementation pending

## Purpose

Phase 8 adds a deterministic Hard Safety Suite to Cycle Simulation Lab. The suite turns critical safety, privacy, permission, uncertainty, AI-overreach, clinical-review, and clinical-truth contracts into S4 release gates.

The suite is synthetic engineering validation. It does not establish clinical efficacy, real-world clinical safety, or human usability, and it does not satisfy Issue #58.

## Design principle

Production-domain engines remain authoritative. Simulation Lab must not duplicate permission, sharing, clinical-copilot, or clinical-review business logic. Instead, Phase 8 uses adapters that invoke the real domain engines and convert observable outcomes into deterministic hard-safety results.

This keeps later labs able to reuse the same gates without creating a parallel policy implementation.

## Existing authoritative engines

Phase 8 will call existing production logic where available:

- `PermissionEvaluator` for generic permission decisions and revocation behavior.
- `RelationshipPermissionFirewall` and `PlayfulEngine` for relationship/playful safety boundaries.
- `AiContextFirewall`, `AiEvidenceValidator`, `AiSafetyValidator`, and `AiOrchestrator` for AI context and action safety.
- `DoctorReviewGate` for clinical-write approval semantics.
- Phase 7 `GroundTruthOracle` for uncertainty-state truth semantics and deterministic provenance.

The existing generic simulation invariants `MissingIsNotZeroInvariant` and `PermissionRevocationInvariant` remain valid foundation checks, but the Phase 8 suite provides the versioned cross-domain report and broader S4 contract layer.

## Package placement

Primary implementation remains in `packages/simulation_domain`.

Expected files:

- `lib/src/hard_safety.dart` — models, adapters, suite runner, canonical serialization.
- `test/hard_safety_test.dart` — deterministic safe-control and deliberate-violation tests.
- `bin/hard_safety_smoke.dart` — seeded machine-readable evidence command.
- `docs/SIMULATION_HARD_SAFETY.md` — operator/developer contract and evidence boundary.
- `.github/workflows/simulation-lab.yml` — hard-safety smoke and artifact publication.

`cycle_simulation_domain.dart` exports the public hard-safety API.

## Dependency direction

`simulation_domain` may depend on production-domain packages for test-orchestration purposes. The dependency direction must remain one way: production packages do not depend on `simulation_domain`.

Expected new package dependencies:

- `cycle_permissions`
- `cycle_sharing`
- `cycle_clinical_copilot`

`cycle_core_domain` remains existing.

## Core model

### HardSafetyInvariantId

A stable identifier namespace for hard gates. Initial IDs:

- `uncertainty.missing-not-known`
- `uncertainty.conflict-not-certain`
- `uncertainty.estimate-not-known`
- `permission.revocation-boundary`
- `ai.context-firewall`
- `ai.evidence-required`
- `ai.autonomous-clinical-action`
- `clinical.doctor-review-gate`
- `relationship.clinical-truth-preserved`

IDs are serialized as strings and remain stable across runs.

### HardSafetyCase

Represents one deterministic contract evaluation request.

Fields:

- `id`
- `invariantId`
- `patientId` or actor scope where applicable
- `observedAt` in UTC
- `seed`
- structured case input

Validation rejects blank IDs, non-UTC timestamps, unsupported invariant IDs, and malformed case payloads.

### HardSafetyResult

Fields:

- `caseId`
- `invariantId`
- `passed`
- `severity` — always `s4` for Phase 8 hard gates
- deterministic `reasonCode`
- UTC `evaluatedAt`
- stable machine-readable evidence

A violation never degrades to a soft score.

### HardSafetyReport

Fields:

- `schemaVersion`
- `seed`
- sorted results
- coverage counts by invariant
- total pass/fail counts
- `passed`
- `syntheticEvidenceOnly: true`

Canonical JSON uses deterministic sorting and stable field order so equivalent validated inputs and seed produce byte-stable output.

## Invariant semantics

### Uncertainty semantic preservation

Phase 8 uses Phase 7 truth semantics as the source of truth.

Hard failures:

- missing truth surfaced as numeric zero or known/normal state;
- conflicting truth surfaced as certain/resolved/known state;
- estimated truth surfaced as known without preserving estimated status.

The adapter must call the Ground Truth Oracle or use its findings rather than reimplementing uncertainty semantics independently.

### Permission revocation boundary

Generic permission access before `revokedAt` may remain valid if the underlying grant permits it. Access at exactly `revokedAt` or later must be denied.

The adapter invokes `PermissionEvaluator` using real `PermissionGrant` and `PermissionRequest` objects. The simulation result fails S4 if production permission logic returns access at or after the revocation boundary.

### AI context firewall

Blocked or non-allowlisted context must cause fail-closed orchestration before model invocation.

The adapter verifies:

- validation disposition is fail;
- model invocation did not occur;
- audit terminates at the context-firewall stage;
- no completed stage is emitted.

### Evidence validation

Claims requiring evidence must fail if evidence is missing or references unavailable evidence IDs.

The suite checks the production `AiEvidenceValidator` result and records deterministic reason codes.

### Autonomous clinical actions

The following candidate actions must fail production safety validation:

- autonomous diagnosis;
- prescribing;
- treatment change;
- direct clinical-record write.

Prompt text never overrides structured action policy.

### Doctor review gate

Clinical writes requiring review must not become commit-capable without an explicit approved `DoctorReviewRecord` matching the proposal ID.

The safe control uses an explicit approved review. Deliberate violations cover absent, mismatched, and rejected review records.

### Clinical truth preserved through Playful Engine

If a clinical truth layer exists, Playful Engine output must preserve it verbatim as the first plain clinical-truth layer.

Hard failures include:

- clinical truth omitted;
- clinical truth text modified;
- clinical truth moved behind or replaced by companion text;
- clinical truth rendered with non-plain tone;
- urgent or review-recommended truth hidden because playfulness is disabled or disallowed.

Playfulness may be omitted entirely without failing. Phase 8 protects clinical truth; it does not require playful output.

## Safe controls and deliberate violations

Every invariant has both:

1. a safe control proving normal allowed behavior still passes; and
2. a deliberate violation proving the hard gate detects the unsafe condition.

Tests must verify exact invariant ID, S4 severity, reason code, evidence, ordering, and determinism.

The suite itself must fail closed on malformed case data. Unsupported case types, malformed timestamps, blank identifiers, or impossible payload combinations produce deterministic validation failure rather than being skipped.

## Determinism and provenance

- All timestamps are UTC.
- Results sort by invariant ID, then case ID, then timestamp.
- Same validated inputs + seed produce byte-stable canonical JSON.
- No wall-clock time participates in evaluation.
- Evidence references stable production-domain IDs where available.
- The seed appears in both report and smoke evidence.

## Coverage

Machine-readable coverage records:

- configured case count;
- evaluated case count;
- passed count;
- failed count;
- per-invariant evaluated/failed counts;
- malformed-input failures.

All initial invariant IDs must be exercised in smoke evidence.

## CI and artifact

`simulation-lab.yml` will run the hard-safety smoke command with a fixed seed after dependency resolution and tests.

It will upload `simulation-hard-safety-evidence` containing canonical JSON evidence.

Phase 8 is not complete until both repository CI and Simulation Lab are `completed/success` on the exact feature HEAD, the PR is merged, and both workflows are `completed/success` on the merge SHA.

## Boundaries deferred to later phases

Phase 8 intentionally does not implement exhaustive attack/fuzz coverage for:

- Phase 9 Permissions & Information-Flow Lab;
- Phase 10 Relationship Lab;
- Phase 11 Privacy Attack Lab;
- Phase 16 Wrong-Patient Safety;
- Phase 21 AI Red-Team expansion;
- Phase 22 Clinical + Playful Collision Lab.

Those phases reuse these hard gates and add scenario breadth, adversarial generation, or domain-specific exploration.

## Issue #58 boundary

Issue #58 must remain open throughout Phase 8. Synthetic safety evidence may support pre-human validation but must never be represented as actual Patient or Doctor usability evidence.

## Acceptance mapping

Issue #221 acceptance criteria map directly to deterministic tests, smoke evidence, CI artifact publication, exact-head workflow verification, post-merge verification, and final confirmation that Issue #58 remains open.
