# Simulation Relationship Behavior Lab

Phase 10 validates relationship-product behavior by exercising the production relationship engines with deterministic synthetic fixtures. Simulation Lab does not reimplement production authorization, visibility, consent, novelty ranking, notification redaction, or clinical-truth policy.

## Contract families

The canonical matrix covers nine production-authoritative families:

- **A — Signals:** explicit/derived selection, lifecycle, supersession, partner scoping, and projected visibility.
- **B — Situation:** Read-the-Room action mapping, relationship weather, deterministic ordering, and low-value micro-moment suppression.
- **C — Memory/context:** Partner Manual and couple-context projection with production visibility ceilings.
- **D — Novelty:** budget, duration, energy, setting, cooldown, do-not-suggest, intimacy gates, deterministic ranking, and no invented fallback.
- **E — Partner Home:** Now / Us / Surprise / Shared Health surfaces built only from authorized partner-scoped inputs.
- **F — Notifications:** notify capability, playful/intimacy content capabilities, generic/category/detailed privacy, and locked-device redaction.
- **G — Playful:** preference/tone behavior while preserving Phase 8 clinical-truth invariants.
- **H — Intimacy:** current bilateral willingness, ask-first/maybe/no/not-tonight, boundaries, cooldown, expiry, and two-direction intimacy permission.
- **I — Presets:** deterministic preset expansion and downstream production permission behavior without copying permission logic.

## Detector strategy

Each `RelationshipBehaviorScenario` declares stable observable `expectedFacts`. `ProductionRelationshipBehaviorObserver` converts fixture payloads into real `cycle_sharing` production types and calls the production engines. `RelationshipBehaviorSuite` performs recursive expected-fact matching only; production policy decisions remain inside the production packages.

All scenario IDs, timestamps, ordering, and JSON serialization are deterministic. Reports are normalized into canonical JSON and carry `syntheticEvidenceOnly=true`.

## Coverage gates

The smoke requires every relationship-behavior family and every mandatory risk tag to have positive coverage. Mandatory tags include scope, lifecycle, permission, visibility, notification privacy, consent, ordering, suppression, no-fallback behavior, clinical truth, Phase 8 reuse, and Phase 9 reuse. Missing mandatory coverage produces a failing `coverage_gap` result.

## Reuse of earlier phases

Phase 10 explicitly reuses the Phase 8 hard-safety clinical-truth gate and Phase 9 permission/information-flow production primitives. It does not create a second permission engine or a second clinical safety policy.

## Smoke and CI evidence

Run locally:

```bash
cd packages/simulation_domain
dart run bin/relationship_behavior_smoke.dart --seed=20260916
```

GitHub Actions uploads the normalized JSON as the exact artifact name:

`simulation-relationship-behavior-evidence`

The evidence must be deterministic, parseable JSON, report `passed=true`, show zero malformed-input failures, and cover all mandatory dimensions.

## Deferred scope

Phase 10 does not expand into Phase 11 Privacy Attack Lab, Phase 16 Wrong-Patient Safety, Phase 21 AI Red-Team expansion, or Phase 22 Clinical + Playful Collision breadth.

## Human-evidence boundary

This phase generates synthetic evidence only. It does **not** satisfy, replace, or close Issue #58, which requires real Patient + Doctor human usability validation and must remain open/reopened until that evidence exists.
