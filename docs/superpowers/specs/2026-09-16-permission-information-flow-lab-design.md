# Phase 9 Permissions & Information-Flow Lab — Design

Date: 2026-09-16
Status: Approved architecture; implementation pending

## Purpose

Phase 9 expands Cycle Simulation Lab from isolated hard-safety contract checks into deterministic, cross-capability permission and information-flow scenario coverage. It verifies that information may move only along paths explicitly authorized by the production permission and sharing engines, and that allowed access never widens into a different action, purpose, recipient, time window, relationship capability, or visibility level.

Phase 9 is synthetic engineering validation. It does not establish clinical efficacy, real-world clinical safety, or human usability, and it does not satisfy Issue #58.

## Design principle

Production-domain engines remain authoritative. Simulation Lab does not implement a second permission system. Phase 9 generates deterministic scenario matrices, invokes the real engines, records normalized decisions/projections, and applies hard information-flow contracts to those observations.

Phase 8 Hard Safety Invariants remain the critical release-gate layer. Phase 9 adds scenario breadth and information-flow coverage around those gates rather than replacing them.

## Existing authoritative engines

Phase 9 will invoke existing production logic directly:

- `PermissionEvaluator` for owner/recipient/action/category/field/purpose/time/data-window decisions.
- `PrivacySimulator` for deterministic batches of generic permission requests.
- `SharePolicy` for independent VIEW / NOTIFY / BACKUP capability projections.
- `RelationshipPermissionFirewall` for purpose-specific relationship capability grants.
- `RelationshipAccessGate` for composed generic + relationship authorization.
- `RelationshipContextProjector` for visibility-restricted information projection.

Production packages must not depend on `simulation_domain`. Dependency direction remains one way.

## Package placement

Primary implementation remains in `packages/simulation_domain`.

Expected Phase 9 files:

- `lib/src/permission_flow.dart` — scenario models, deterministic generator, production adapters, normalized observations, evaluator, canonical report serialization.
- `test/permission_flow_test.dart` — deterministic matrix, safe-control, escalation, leakage, malformed-input, and round-trip tests.
- `bin/permission_flow_smoke.dart` — fixed-seed production-only scenario evidence command.
- `docs/SIMULATION_PERMISSION_FLOW.md` — operator/developer contract, coverage dimensions, S4 semantics, and evidence boundary.
- `.github/workflows/simulation-lab.yml` — smoke execution and artifact publication.

`lib/simulation_domain.dart` exports the public Phase 9 API.

## Scenario strategy

Phase 9 uses a deterministic risk-oriented matrix rather than an exhaustive Cartesian product. The generator combines explicit boundary cases, pairwise coverage across independent permission dimensions, and adversarial escalation cases.

This avoids two failure modes:

1. a small hand-authored suite that misses interactions between dimensions; and
2. a combinatorial explosion that produces large but low-value test volume.

The matrix is stable for the same schema version and seed. Scenario IDs derive only from stable logical inputs, not wall-clock state or collection iteration order.

## Scenario dimensions

The initial matrix covers the following production dimensions.

### Actor scope

- correct owner + correct recipient;
- wrong recipient;
- wrong owner;
- owner equal to recipient where a relationship policy forbids it;
- unrelated grant present but not matching the request.

### Generic permission action

- `view`;
- `notify`;
- `backup`;
- `export`.

No action implies another. In particular, VIEW does not imply NOTIFY, BACKUP, or EXPORT.

### Scope

- category match / category mismatch;
- field match / field mismatch;
- explicit purpose match / purpose mismatch;
- no purpose supplied where the production grant semantics permit category/action-only evaluation;
- grant validity start boundary;
- grant validity end boundary;
- exact revocation boundary;
- resource data-window lower boundary;
- resource data-window upper boundary;
- resource before/after allowed historical range.

### Relationship capability

- `view`;
- `notify`;
- `relationshipIntelligence`;
- `playful`;
- `intimacy`.

Generic permission alone never creates a Relationship/Playful/Intimacy capability. Relationship capability alone never bypasses a required generic VIEW or NOTIFY gate.

### Visibility

- `private`;
- `engineOnly`;
- `abstractShared`;
- `fullyShared`.

Visibility is treated as an information-flow ceiling. A projection may become more restrictive than either source/item or grant policy requires, but never less restrictive.

## Core models

### PermissionFlowScenario

Represents one deterministic production-policy exercise.

Fields:

- `id` — stable scenario ID;
- `schemaVersion`;
- `seed`;
- `at` — UTC virtual evaluation time;
- `ownerId`;
- `recipientId`;
- `kind` — generic, share-policy, relationship, composed-access, or projection;
- structured request/input description;
- expected contract class, not a duplicated production decision.

The scenario does not encode a second copy of policy. Its expectation describes only hard information-flow properties such as `mustDeny`, `mustNotExposeRaw`, `mustRequireBothGates`, or `mustKeepActionIndependent`.

### PermissionFlowObservation

A normalized record derived from production engines. Depending on scenario kind it may include:

- generic decision allowed/reason/matched grant;
- independent VIEW/NOTIFY/BACKUP capability booleans;
- relationship decision allowed/reason/visibility/matched grant;
- composed-gate decision and matched generic/relationship grants;
- projection presence, effective visibility, and raw-value exposure flag.

Observations contain only facts required for contract evaluation and evidence.

### PermissionFlowResult

Fields:

- `scenarioId`;
- `passed`;
- `severity`;
- deterministic `reasonCode`;
- UTC `evaluatedAt`;
- stable evidence map.

Any information-flow contract violation is S4. Safe production denials and correctly redacted projections are passing results.

### PermissionFlowCoverage

Machine-readable coverage records at least:

- total scenarios;
- evaluated / passed / failed;
- malformed-input failures;
- per-scenario-kind counts;
- per-action counts;
- per-relationship-capability counts;
- per-visibility counts;
- boundary counts for grant start/end/revocation/data windows;
- escalation attempt counts;
- leakage attempt counts.

### PermissionFlowReport

Fields:

- schema version;
- seed;
- sorted results;
- coverage;
- overall `passed`;
- `syntheticEvidenceOnly: true`.

Canonical JSON must be byte-stable for the same validated inputs and seed.

## Hard information-flow contracts

Phase 9 treats the following observed production outcomes as S4 failures.

### Recipient / owner isolation

A grant for another owner or recipient must not authorize the request. A wrong-recipient or wrong-owner request that succeeds is an S4 failure.

### Action independence

Permission actions are independent. A grant containing VIEW only must not authorize NOTIFY, BACKUP, or EXPORT. Equivalent checks are included for each action pair where an unauthorized action is attempted.

Failure reason: `action_escalation`.

### Category / field / purpose containment

A matching action cannot widen beyond its category, field, or explicit purpose scope. Success outside any configured scope is an S4 failure.

Stable reason codes:

- `category_scope_escape`;
- `field_scope_escape`;
- `purpose_scope_escape`.

### Temporal authorization containment

Access before grant activation, at/after grant validity end, or at/after revocation must fail. Phase 8's exact revocation contract is reused as the hard boundary.

Stable reason codes:

- `grant_time_escape`;
- `revocation_breach`.

### Historical data-window containment

A request for resource data outside the grant's `dataFrom` / `dataUntil` range must not succeed.

Failure reason: `data_window_escape`.

### Generic / relationship separation

Generic permission must not imply `relationshipIntelligence`, `playful`, or `intimacy`. Relationship-category capability must not imply generic data access.

Failure reason: `relationship_capability_escalation`.

### Composed gate integrity

For composed VIEW and NOTIFY flows, both the generic permission gate and the matching relationship capability gate must authorize access. If either side denies, the composed gate must deny.

Failure reason: `composed_gate_bypass`.

Unsupported generic/relationship capability pairings remain production validation errors and are exercised as malformed/fail-closed scenarios, not normalized into permissive outcomes.

### Visibility ceiling

`private` and `engineOnly` information must not expose a partner-facing raw value. `abstractShared` may indicate a shareable abstract projection but must not expose the raw source value. Only effective `fullyShared` visibility may expose the raw value.

Stable reason codes:

- `private_data_exposed`;
- `engine_only_data_exposed`;
- `abstract_data_exposed`.

The effective projection is the more restrictive of item visibility and grant visibility; neither side may widen the other.

### Default deny

No matching active grant means deny. Presence of unrelated, expired, revoked, wrong-purpose, wrong-field, or wrong-recipient grants must not turn default deny into allow.

Failure reason: `default_deny_bypass`.

## Safe controls and deliberate violations

Every contract family has at least:

1. a positive safe control demonstrating intended production authorization;
2. one or more negative production cases demonstrating correct denial/redaction; and
3. where needed, a test-only injected normalized observation proving the detector turns an impossible observed breach into S4.

Injected observations remain detector tests only. `permission_flow_smoke.dart` uses production adapters exclusively.

## Malformed input and fail-closed behavior

Malformed scenario input must never be skipped or silently normalized into a pass. Deterministic malformed cases include:

- blank IDs;
- non-UTC evaluation time;
- unsupported schema version;
- unsupported scenario kind;
- owner/recipient omissions;
- impossible expectation/input combinations;
- invalid relationship visibility/capability combinations rejected by production constructors;
- composed generic/relationship action mismatch.

The suite records deterministic fail-closed evidence and a non-zero malformed-input coverage count.

## Determinism and ordering

- No wall-clock time participates in evaluation.
- All virtual timestamps are UTC.
- Scenarios sort by stable scenario ID before execution/evidence serialization.
- Results sort by scenario ID and deterministic reason/evidence keys.
- Sets/maps are canonicalized before JSON serialization.
- Same validated inputs + seed produce byte-identical JSON.
- JSON round-trip preserves semantic equality.

## Production smoke

`permission_flow_smoke.dart --seed=20260916` builds the canonical Phase 9 scenario matrix and executes it through production adapters only.

The smoke must exercise all initial contract families and required coverage dimensions. Any S4 result or malformed production scenario makes the command exit non-zero.

The canonical production smoke should include enough pairwise/adversarial breadth to cover interactions without depending on an exhaustive Cartesian product. The exact case count may evolve with the schema, but coverage requirements are versioned and validated so accidental scenario loss fails tests.

## CI artifact

`simulation-lab.yml` runs the Phase 9 smoke after package tests and writes:

`permission-flow-evidence.json`

The uploaded artifact name is exactly:

`simulation-permission-flow-evidence`

The artifact is synthetic engineering evidence only.

## Issue #58 boundary

Issue #58 must remain `open/reopened` throughout Phase 9. Permission-flow simulation, deterministic evidence, and synthetic coverage do not count as Patient or Doctor usability sessions.

If automation or merge behavior closes #58 indirectly, it must be reopened immediately.

## Deferred scope

Phase 9 does not absorb later labs:

- Phase 10 owns broader relationship-behavior scenarios beyond authorization flow.
- Phase 11 owns adversarial privacy-attack generation beyond the permission-flow matrix.
- Phase 16 owns wrong-patient clinical safety breadth.
- Phase 21 owns AI red-team breadth.
- Phase 22 owns Clinical + Playful collision breadth.

Phase 9 provides reusable permission-flow scenario and evidence primitives for those phases.

## Completion gate

Phase 9 is complete only when:

- the approved spec and implementation plan are committed on a Phase 9 feature branch;
- all deterministic TDD cycles are complete;
- format/analyze/full package tests and production smoke pass locally in the Flutter stable Docker image;
- the PR contains only Phase 9 changes;
- exact feature-head repository CI and Simulation Lab are `completed/success`;
- `simulation-permission-flow-evidence` exists on the successful feature-head Simulation Lab run;
- the PR is merged to `main`;
- exact merge-SHA repository CI and Simulation Lab are `completed/success`;
- the post-merge `simulation-permission-flow-evidence` artifact exists;
- the Phase 9 tracking issue acceptance checklist is fully checked and closed as completed;
- Issue #58 is re-fetched and remains `open/reopened`.
