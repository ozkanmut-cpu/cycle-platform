# Phase 10 — Relationship Behavior Lab Design

## Status

Approved design for Simulation Lab Phase 10.

Issue: #226
Branch: `phase-10-relationship-behavior-lab`

This phase is synthetic engineering validation only. It does not satisfy or close Issue #58, which remains the real Patient + Doctor human usability blocker.

## Goal

Build a deterministic Relationship Behavior Lab that exercises the real production relationship stack under realistic, adversarial, and boundary-heavy partner scenarios without reimplementing production authorization, privacy, consent, or behavior policy inside Simulation Lab.

Phase 10 expands behavioral breadth after:

- Phase 8 Hard Safety Invariants, which owns reusable S4 release gates;
- Phase 9 Permissions & Information-Flow Lab, which owns generic/relationship authorization composition and information-flow boundaries.

Phase 10 must reuse those layers rather than create parallel rules.

## Non-goals

Phase 10 does not implement:

- Phase 11 adversarial privacy-attack generation;
- Phase 16 wrong-patient clinical-safety breadth;
- Phase 21 AI red-team expansion;
- Phase 22 Clinical + Playful collision breadth;
- real-human usability evidence;
- new product behavior or policy unless a production defect is discovered and explicitly fixed as a separate production change.

## Design principles

### Production engines are authoritative

Simulation Lab may generate inputs, orchestrate calls, normalize observable outputs, and assert invariants. It must not copy production branching logic such as consent interpretation, capability checks, visibility ranking, lifecycle handling, novelty filtering, or notification redaction.

### Behavior is tested through contracts, not implementation copies

Each scenario declares an expected contract family and expected observable property. The evaluator then invokes production engines and verifies the output against a small set of Phase 10 detector contracts. Detectors assert safety and behavioral properties, not alternative business logic.

### Risk-oriented coverage beats Cartesian explosion

The suite uses deterministic pairwise/adversarial scenarios that deliberately combine high-risk boundaries. It does not enumerate every possible cross-product of partner state, grant, device state, content type, timing, and presentation mode.

### Fail closed

Malformed scenario input, invalid actor scope, impossible lifecycle timestamps, invalid enum/version state, unexpected production exception classes, missing required evidence, or detector ambiguity must fail the scenario and therefore fail the smoke report.

### Determinism is part of the contract

Given the same validated scenario set and seed, the canonical output must be byte-stable. IDs, timestamps, ordering, reason codes, and JSON serialization must remain stable and UTC-normalized.

## Production engines under test

Phase 10 directly invokes the existing production implementations in `packages/sharing`.

Required engines and coordinators:

- `RelationshipSignalEngine`
- `PartnerSignalProjector`
- `RelationshipSituationEngine`
- `CoupleMemoryEngine`
- `CoupleContextEngine`
- `NoveltyEngine`
- `RelationshipHomeOrchestrator`
- `PartnerExperienceCoordinator`
- `RelationshipNotificationPipeline`
- `PlayfulEngine`
- `IntimacyEngine`
- `RelationshipPresetExpander`

Phase 9 primitives remain authoritative where access checks are required:

- `RelationshipPermissionFirewall`
- `RelationshipAccessGate`
- `RelationshipContextProjector`
- generic `PermissionEvaluator` / `SharePolicy` composition where applicable.

Phase 8 hard-safety detectors remain authoritative for clinical-truth preservation and other reusable S4 invariants.

## Architecture

### 1. Scenario model

Add versioned deterministic models in `packages/simulation_domain`:

- `RelationshipBehaviorScenario`
- `RelationshipBehaviorScenarioFamily`
- `RelationshipBehaviorExpectedContract`
- `RelationshipBehaviorResult`
- `RelationshipBehaviorFinding`
- `RelationshipBehaviorCoverage`
- `RelationshipBehaviorReport`

Every scenario contains:

- schema version;
- stable scenario ID;
- deterministic seed fragment;
- actor IDs and relationship direction;
- UTC evaluation instant;
- scenario family;
- production input fixture references or inline deterministic fixtures;
- expected contract identifiers;
- risk tags;
- whether the scenario is a safe control or adversarial case.

No scenario contains a reimplemented expected production decision tree.

### 2. Production adapter layer

Create one narrow Phase 10 adapter/orchestrator that maps validated simulation fixtures into production types and calls the production engines directly.

The adapter may:

- build production model objects from deterministic fixtures;
- invoke engines;
- convert outputs into stable observation records;
- capture production exceptions as explicit fail-closed observations.

The adapter must not:

- decide whether a permission should be granted independently;
- infer consent outside `IntimacyEngine`;
- rank novelty outside `NoveltyEngine`;
- synthesize relationship weather outside `RelationshipSituationEngine`;
- widen visibility or presentation detail;
- invent fallback content when production returns empty.

### 3. Detector layer

Phase 10 detectors consume only stable observations and assert contract-level properties.

Detector families:

- scope isolation;
- lifecycle and precedence;
- deterministic ordering;
- suppression/no-fallback;
- visibility and raw-value boundary preservation;
- notification privacy/redaction;
- capability composition reuse;
- consent/willingness/boundary preservation;
- Playful clinical-truth preservation via Phase 8 gate reuse;
- malformed-input fail-closed behavior;
- canonical evidence determinism.

Findings use stable reason codes. Phase 10 should prefer a small explicit enum/string vocabulary over free-form prose as machine evidence.

## Contract families

### A. Relationship signals and projection

Exercise `RelationshipSignalEngine` and `PartnerSignalProjector`.

Required scenarios include:

- explicit signal supersedes derived signal in the same logical domain;
- newer valid version deterministically supersedes older version according to production ordering;
- expired signals do not become active;
- revoked signals do not become active at or after the revocation instant;
- independent logical domains remain independent;
- custom signals require stable custom keys;
- wrong owner or wrong recipient never projects to the partner;
- a correctly scoped signal still requires the production view grant before projection;
- ordering remains deterministic across equivalent input permutations.

Phase 10 must not duplicate the signal-selection comparator; it validates production output ordering and selected IDs.

### B. Read-the-Room and relationship weather

Exercise `RelationshipSituationEngine`.

Required scenarios include:

- explicit space signal maps to production give-space behavior;
- scope/permission failures produce no unauthorized action;
- priority and recency produce deterministic action selection;
- relationship weather stays categorical rather than becoming a synthetic relationship score;
- multiple permitted signals may produce mixed weather without judgmental reinterpretation;
- zero-log micro-moment suppression removes low-value prompts;
- recent interaction suppresses unnecessary prompting;
- highest-value low-burden micro-moment wins deterministically;
- expired/revoked room signals are ignored.

The Simulation Lab may inspect output categories, but must not calculate its own weather score or action ranking.

### C. Couple memory and shared context

Exercise `CoupleMemoryEngine` and `CoupleContextEngine`.

Required scenarios include:

- Partner Manual exposes raw memory only when production visibility and grant rules allow it;
- engine-only memory may be used by production internals but never becomes partner-facing raw content;
- abstract visibility may surface an abstraction while preserving the raw-value boundary;
- view permission does not imply playful, intimacy, or relationship-intelligence purpose permission;
- newest valid memory version wins deterministically;
- expired, revoked, or wrong-partner memory never projects;
- arbitrary input ordering yields stable output ordering;
- shared context preserves the most restrictive production visibility and correct recipient scope.

Phase 10 reuses Phase 9 information-flow detectors for raw-value exposure and visibility widening.

### D. Novelty and safe surprise behavior

Exercise `NoveltyEngine`.

Required scenarios include:

- do-not-suggest tags are hard filters;
- budget, duration, energy, and setting constraints are hard filters;
- recently used candidates are suppressed by production cooldown semantics;
- relationship-intelligence permission is required;
- intimacy ideas require the production intimacy conditions and authorization;
- preferred tags affect ranking only through production ranking logic;
- ties/order remain deterministic;
- when no candidate qualifies, the result is empty rather than an invented fallback.

The Simulation Lab must not create a backup suggestion when production returns an empty list.

### E. Partner Home and end-to-end partner experience

Exercise `RelationshipHomeOrchestrator` and `PartnerExperienceCoordinator`.

Required surfaces:

- Now;
- Us;
- Surprise;
- Shared Health.

Required scenarios include:

- correctly scoped authorized inputs can build expected surface classes;
- zero-log suppressed micro-moments are absent;
- engine-only memories remain absent from partner-facing surfaces;
- abstract memory may surface without raw value;
- Shared Health requires correct production projection and partner visibility;
- fully shared health may expose raw value only when production rules allow it;
- surprises are deterministic;
- wrong-partner scope fails closed across the coordinator;
- a visible input does not automatically become usable by relationship intelligence.

This contract family is the primary integration surface for Phase 10, but it does not replace direct tests of the specialized engines.

### F. Relationship notifications

Exercise `RelationshipNotificationPipeline`.

Required scenarios include:

- NOTIFY is required even when VIEW exists;
- NOTIFY may authorize a notification without granting unrelated VIEW access;
- generic privacy mode never exposes detail;
- category-only mode exposes category label only, not private detail;
- detailed-when-unlocked falls back to generic when the device is locked;
- detailed content may appear only when the device state and production grants allow it;
- playful notification requires NOTIFY plus PLAYFUL;
- intimacy notification requires NOTIFY plus INTIMACY;
- playful-intimacy notification requires both content capabilities plus NOTIFY;
- revoked/wrong-recipient grants suppress presentation.

Phase 10 does not duplicate the content-capability mapping; it verifies observed presentation behavior from the production pipeline.

### G. Playful relationship behavior

Exercise `PlayfulEngine` while reusing Phase 8 hard-safety assertions.

Required scenarios include:

- clinical truth remains first and byte/semantic-equivalent to the production input truth layer;
- playful companion never replaces or rewrites clinical truth;
- playful-purpose authorization is required where production requires it;
- spicy tone requires the production intimacy condition;
- serious/urgent opt-in behavior is exercised only to prove the Phase 8 safety gate remains intact;
- user preference may keep a companion layer only where production permits it.

Phase 10 does not broaden into the full Clinical + Playful collision matrix. That remains Phase 22.

### H. Intimacy consent, willingness, and boundaries

Exercise `IntimacyEngine`.

Required scenarios include:

- long-term preference alone never becomes current consent;
- absence of response is not consent;
- two current affirmative willingness records may create only the production-defined time-limited mutual state;
- `no` and `notTonight` suppress matching;
- `askFirst` or `maybe` produces ask-first behavior, never consent;
- hard boundary blocks even when both participants currently say yes;
- ask-first boundary downgrades mutual yes to ask-first;
- cooldown suppresses repeated intimacy suggestions;
- both directions require explicit intimacy-purpose authorization;
- long-term not-interested preference prevents an intimacy match where production defines that behavior;
- stale, revoked, wrong-partner, malformed, or contradictory fixtures fail closed.

Phase 10 reports observable `IntimacyDecisionKind` and stable reasons only. It must not infer consent independently.

### I. Relationship preset expansion

Exercise `RelationshipPresetExpander`.

Required scenarios include:

- every non-custom preset expands deterministically;
- generated grants preserve owner/recipient/category/version semantics;
- custom handling remains explicit and is not silently substituted;
- preset expansion does not bypass later production permission evaluation;
- arbitrary input ordering does not change canonical evidence.

A preset is treated as input generation, not authorization proof.

## Scenario strategy

Use a curated deterministic matrix rather than exhaustive combinations.

Each contract family must include:

- at least one safe control;
- at least one wrong-scope or wrong-recipient case when applicable;
- at least one lifecycle/time-boundary case when applicable;
- at least one permission/capability boundary case when applicable;
- at least one deterministic ordering/tie case when applicable;
- at least one malformed-input fail-closed case;
- at least one adversarial case designed to trigger a detector.

Cross-family scenarios should deliberately combine risky boundaries, for example:

- wrong recipient + valid-looking explicit signal + valid unrelated grant;
- locked device + intimacy notification + correct NOTIFY but missing INTIMACY;
- fully shared health + relationship intelligence missing;
- two current intimacy yes values + active hard boundary;
- preferred novelty tag + do-not-suggest tag conflict;
- engine-only memory + otherwise valid Partner Home build;
- urgent clinical truth + playful opt-in while Phase 8 truth-preservation gate remains active.

The exact scenario count is not hard-coded in the design; implementation should choose the smallest matrix that covers every required family and dimension with explicit machine-readable coverage.

## Coverage model

`RelationshipBehaviorCoverage` must expose at least:

- configured scenario count;
- evaluated scenario count;
- passed/failed counts;
- malformed-input failure count;
- safe-control count;
- adversarial count;
- contract-family coverage map;
- scope-isolation coverage;
- lifecycle-boundary coverage;
- permission/capability-boundary coverage;
- visibility/redaction coverage;
- consent/boundary coverage;
- deterministic-ordering coverage;
- no-fallback/suppression coverage;
- Phase 8 hard-safety reuse count;
- Phase 9 permission-flow reuse count.

Coverage gaps in mandatory families fail the smoke run.

## Severity and findings

Phase 10 findings use the existing Simulation Lab safety vocabulary where possible.

Relationship behavior violations that can expose private data, bypass consent, cross partner scope, or rewrite clinical truth are treated as S4 through reused Phase 8/9 gates.

Lower-severity deterministic behavior mismatches may still fail Phase 10 because this is a contract-validation phase. The report must distinguish severity from pass/fail status.

Suggested stable finding categories:

- `scope_violation`
- `lifecycle_violation`
- `permission_escalation`
- `visibility_leak`
- `notification_privacy_violation`
- `consent_boundary_violation`
- `suppression_violation`
- `invented_fallback`
- `ordering_nondeterminism`
- `clinical_truth_violation`
- `malformed_input`
- `coverage_gap`

## Canonical evidence

Add a production-only smoke command:

`packages/simulation_domain/bin/relationship_behavior_smoke.dart`

The smoke command must:

- accept a fixed seed argument;
- use only production engines plus Simulation Lab orchestration/detectors;
- generate deterministic canonical JSON;
- print or write a stable report;
- exit non-zero if validation fails, a mandatory coverage dimension is absent, a detector fires unexpectedly, or malformed input does not fail closed.

Canonical JSON rules:

- UTF-8;
- UTC ISO-8601 timestamps;
- stable field ordering;
- stable list ordering;
- no wall-clock timestamps;
- no random UUIDs;
- no host-specific paths;
- no environment-dependent values.

The same seed and validated input fixtures must produce byte-identical output across repeated runs.

## CI integration

Extend `.github/workflows/simulation-lab.yml` with:

1. Phase 10 test execution as part of the existing package test suite;
2. a dedicated `relationship_behavior_smoke.dart` step;
3. upload of exact artifact name:

`simulation-relationship-behavior-evidence`

Artifact requirements:

- contains the canonical relationship-behavior JSON report;
- is uploaded only after the smoke succeeds;
- is associated with the exact workflow head SHA;
- remains machine-readable without parsing console logs.

## Tests

Required test classes:

- scenario validation tests;
- deterministic same-seed equivalence;
- canonical byte-stability across repeated smoke generation;
- JSON round-trip preserving semantics;
- malformed scenario fail-closed tests;
- one or more tests for every contract family A–I;
- detector self-tests that prove deliberate violations are detected;
- integration tests proving Phase 8 and Phase 9 primitives are reused rather than shadowed;
- stable ordering tests using permuted equivalent inputs.

Tests should call production engines directly through the Phase 10 adapter. Test-only substitute engines are allowed only for detector self-tests and must be clearly isolated from production-evidence smoke paths.

## Expected implementation surface

Primary expected files:

- `packages/simulation_domain/lib/src/relationship_behavior.dart`
- `packages/simulation_domain/lib/simulation_domain.dart`
- `packages/simulation_domain/test/relationship_behavior_test.dart`
- `packages/simulation_domain/bin/relationship_behavior_smoke.dart`
- `.github/workflows/simulation-lab.yml`
- `docs/SIMULATION_RELATIONSHIP_BEHAVIOR.md`
- implementation plan under `docs/superpowers/plans/`

Production `packages/sharing` files should remain unchanged unless the Phase 10 suite exposes a real production defect. Any such defect must be fixed with its own focused tests and explicitly documented; the Simulation Lab must never compensate for it by embedding a shadow policy.

## Completion gates

Phase 10 is complete only when all of the following are true:

1. design and implementation plan are committed on the Phase 10 branch;
2. Issue #226 acceptance criteria are backed by real test/evidence results;
3. local/container verification passes: format, analyze, tests, smoke, deterministic repeat, diff checks, placeholder scan, workflow parse;
4. exact feature HEAD repository CI is `completed/success`;
5. exact feature HEAD Simulation Lab is `completed/success`;
6. exact feature-head artifact `simulation-relationship-behavior-evidence` exists and matches the feature HEAD;
7. code review has no unresolved blocking findings;
8. #58 is confirmed `open/reopened` immediately before merge;
9. PR is merged with an expected-head guard;
10. `main` equals the resulting merge SHA;
11. exact merge SHA repository CI is `completed/success`;
12. exact merge SHA Simulation Lab is `completed/success`;
13. exact merge-SHA relationship-behavior artifact exists and its canonical JSON passes verification;
14. #226 acceptance checklist is fully updated from evidence and issue is `closed/completed`;
15. #58 is re-fetched and remains `open/reopened`;
16. only then may Phase 10 be reported `[x] COMPLETE`.

Queued or in-progress workflows never count as green.

## Human-evidence boundary

All Phase 10 results are synthetic engineering evidence. They may demonstrate that production relationship contracts behave deterministically under configured scenarios, but they do not demonstrate that real Patients or Doctors understand, trust, or can successfully use the product.

Issue #58 must remain open/reopened. Phase 10 must not change the V1 human-usability TODO state.

## Deferred follow-on phases

- Phase 11 — Privacy Attack Lab: adversarial privacy-attack generation and broader exfiltration attempts.
- Phase 16 — Wrong-Patient Safety: cross-patient clinical action and identification hazards.
- Phase 21 — AI Red-Team expansion: broader adversarial AI behavior beyond existing gates.
- Phase 22 — Clinical + Playful Collision Lab: exhaustive mixed clinical/playful context collisions.

These later phases should reuse Phase 8 hard gates, Phase 9 permission-flow primitives, and Phase 10 relationship-behavior fixtures rather than create parallel policy logic.
