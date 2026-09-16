# Simulation Lab Hard Safety Invariants

## Purpose

Phase 8 turns Cycle's critical synthetic safety contracts into deterministic S4 release gates. It is engineering evidence only: it does not establish clinical efficacy, real-world clinical safety, or human usability. Issue #58 remains open until real Patient and Doctor usability sessions are completed.

## Authority boundary

Production-domain engines are authoritative. The Simulation Lab invokes `PermissionEvaluator`, Phase 7 `GroundTruthOracle`, `AiOrchestrator`, `AiEvidenceValidator`, `AiSafetyValidator`, `DoctorReviewGate`, and `PlayfulEngine` through thin adapters. It does not implement a second copy of permission, AI, clinical-review, uncertainty, or relationship policy.

Detector self-tests may inject normalized impossible outcomes to prove that a hypothetical contract breach produces an S4 failure. These injected outcomes are test-only and are never used by the CI smoke command.

## Initial hard gates

The versioned suite covers nine invariant IDs:

- `uncertainty.missing-not-known`
- `uncertainty.conflict-not-certain`
- `uncertainty.estimate-not-known`
- `permission.revocation-boundary`
- `ai.context-firewall`
- `ai.evidence-required`
- `ai.autonomous-clinical-action`
- `clinical.doctor-review-gate`
- `relationship.clinical-truth-preserved`

Every violation is severity S4 and fails the report. Missing data cannot become known/zero, conflicting data cannot become certain, estimated data cannot silently become known, access at or after revocation cannot succeed, blocked AI context cannot cross the firewall, unsupported evidence and autonomous clinical actions must be rejected, clinical writes cannot bypass doctor approval, and clinical truth must remain first/plain/verbatim through Playful Engine composition.

## Determinism and evidence

All case/result timestamps are UTC. Result ordering is stable by invariant ID, case ID, and timestamp. Equivalent validated inputs with the same seed produce byte-stable canonical JSON. The report includes per-invariant coverage, pass/fail counts, malformed-input failures, and `syntheticEvidenceOnly: true`.

Run locally from `packages/simulation_domain`:

```bash
dart pub get
dart run bin/hard_safety_smoke.dart --seed=20260916
```

The smoke uses production adapters only and must exit non-zero if any hard gate fails.

## Deferred breadth

Phase 8 establishes the reusable hard gates, not exhaustive attack generation. Phase 9 expands permission/information-flow scenarios; Phase 10 relationship behavior; Phase 11 privacy attacks; Phase 16 wrong-patient safety; Phase 21 AI red-team breadth; and Phase 22 Clinical + Playful collision breadth. Those phases should reuse these gates rather than creating parallel policy logic.
