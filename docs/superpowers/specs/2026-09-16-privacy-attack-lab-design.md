# Phase 11 — Privacy Attack Lab Design

Date: 2026-09-16
Status: approved architecture, pending written-spec review
Issue: #228
Branch: `phase-11-privacy-attack-lab`
Base main SHA: `81e72ba4fb722dbcedd7d38835a483c3d98f0a9d`

## 1. Goal

Phase 11 adds a deterministic Privacy Attack Lab to Cycle Simulation Lab.

The lab generates adversarial privacy-boundary mutations from validated safe-control fixtures, executes those mutations against the real production permission/sharing/privacy/revocation/key/relay engines, and emits canonical machine-readable evidence describing whether each attack was contained.

The lab is an attack generator and evidence harness, not a second permission system, second relationship-privacy system, or second cryptographic policy engine.

All Phase 11 evidence is synthetic engineering evidence only. It never satisfies or closes Issue #58.

## 2. Non-goals

Phase 11 does not implement:

- Phase 16 wrong-patient clinical-safety breadth;
- Phase 21 AI red-team expansion;
- Phase 22 Clinical + Playful collision breadth;
- patient, partner, or doctor UI journey testing;
- general-purpose fuzzing;
- metamorphic testing;
- mutation testing;
- cryptographic algorithm breaking;
- timing, cache, power, or hardware side-channel analysis;
- new production authorization semantics merely to make the simulation pass;
- human usability validation.

If Phase 11 discovers a real production defect, that defect must be fixed explicitly in the authoritative production package and covered by a production regression test. Simulation-domain code must not hide the defect by implementing an alternate policy.

## 3. Existing authority reused

Phase 11 reuses the existing production authority established by earlier phases.

### Generic permissions

- `PermissionEvaluator`
- `PrivacySimulator`
- `PermissionGrant`
- `PermissionScope`
- `PermissionAction`

These remain authoritative for owner/recipient/action/category/field/purpose/time/data-window decisions.

### Sharing and composed authorization

- `SharePolicy`
- `RelationshipPermissionFirewall`
- `RelationshipAccessGate`
- `RelationshipContextProjector`

These remain authoritative for independent sharing capabilities, relationship capabilities, composed authorization, and visibility ceilings.

### Notification privacy

- `RelationshipNotificationPipeline`
- `NotificationPrivacyMode`

These remain authoritative for notify capability, content-capability requirements, generic/category-only/detailed presentation, and lock-state redaction.

### Revocation and recipient keys

- `PermissionEvaluator.revocationEffect`
- `SharingRevocationCoordinator`
- `RecipientKeyRegistry`
- `RecipientKeyState`

These remain authoritative for revocation effects and recipient-key rotation state.

### Relay binding and encryption

- `SharingTransport`
- `OpaqueRelayEnvelope`
- production crypto package primitives used by the transport

These remain authoritative for recipient binding, associated data, encryption, and decryption behavior.

### Earlier Simulation Lab phases

- Phase 8 hard-safety detector conventions are reused for S4 release-gate semantics.
- Phase 9 permission/information-flow scenario semantics and production adapters are reused where appropriate.
- Phase 10 relationship privacy surfaces are reused where attack generation targets relationship visibility or relationship notifications.

Production packages must never depend on `simulation_domain`.

## 4. Design approach

Phase 11 uses a deterministic attack generator rather than a manually exhaustive attack table or unconstrained fuzzing.

Each generated adversarial scenario begins from a known safe-control fixture. The generator mutates one attack dimension, or an explicitly named pair of interacting dimensions, while preserving every unrelated fixture field.

This produces three properties:

1. the attack is attributable to a known mutation;
2. failures are replayable and understandable;
3. attack breadth can expand without reproducing production decision logic.

The generator never decides whether a mutated request should be authorized by re-running copied business rules. It assigns only a minimal containment contract such as “wrong recipient must not gain access” or “engine-only content must not expose raw value.” Production engines determine the observed outcome.

## 5. Proposed simulation-domain model

Create `packages/simulation_domain/lib/src/privacy_attack.dart` and export it from `packages/simulation_domain/lib/simulation_domain.dart`.

### `PrivacyAttackFamily`

Stable families:

- `identitySubstitution`
- `actionEscalation`
- `scopeSubstitution`
- `temporalReplay`
- `composedGrantConfusion`
- `relationshipCapabilityEscalation`
- `visibilityExfiltration`
- `notificationLeakage`
- `revocationAndKeyReplay`
- `relayRecipientBinding`

### `PrivacyAttackMutation`

A normalized description of what was changed relative to the safe control.

Fields:

- stable mutation ID;
- attack family;
- mutation dimensions;
- source-control scenario ID;
- canonical before/after descriptors that contain no secret plaintext;
- whether this is a single-axis or approved paired mutation.

The mutation object describes input change only. It does not compute authorization.

### `PrivacyAttackScenario`

Fields:

- stable scenario ID;
- schema version;
- seed fragment;
- UTC evaluation instant;
- source-control ID;
- owner ID;
- intended recipient ID;
- attempted recipient ID where relevant;
- family;
- target production surface;
- mutation;
- canonical fixture payload;
- minimal containment contract ID;
- risk tags;
- safe-control/adversarial marker.

Construction validates stable required fields, supported schema version, UTC timestamps, and family/payload consistency required for deterministic adapter dispatch.

### `PrivacyAttackObservation`

Normalized production observation only.

Possible stable fields include:

- allowed/denied;
- projected/not projected;
- raw value exposed/not exposed;
- notification emitted/suppressed;
- notification redacted/not redacted;
- matched generic grant ID;
- matched relationship grant ID;
- effective visibility;
- recipient key version/state;
- revocation result summary;
- relay decrypt accepted/rejected;
- stable production reason code where available.

The observation must not expose secret plaintext, raw cryptographic keys, or environment-specific values.

### `PrivacyAttackResult`

Fields:

- scenario identity;
- attack family;
- pass/fail;
- severity;
- stable finding category;
- stable reason code;
- normalized observation;
- deterministic diagnostics;
- malformed-input marker.

### `PrivacyAttackCoverage`

Tracks configured/evaluated/pass/fail/malformed counts plus coverage maps for:

- attack family;
- production target surface;
- generic action;
- scope dimension;
- temporal boundary;
- relationship capability;
- relationship visibility;
- notification privacy mode;
- revocation/key surface;
- relay surface;
- safe-control/adversarial counts;
- Phase 8 reuse count;
- Phase 9 reuse count;
- Phase 10 privacy-surface reuse count where applicable.

### `PrivacyAttackReport`

Contains:

- schema version;
- seed;
- UTC provenance;
- normalized results;
- coverage;
- pass/fail summary;
- `syntheticEvidenceOnly: true`.

JSON field order and list order must be canonical.

## 6. Attack generator contract

`PrivacyAttackGenerator` receives canonical safe controls and a stable seed. It emits deterministic safe-control + adversarial pairs.

The generator may select among predefined mutation templates using the simulation deterministic random source, but generated output must not depend on wall-clock time, host state, iteration order of unordered collections, or random UUIDs.

The generator is constrained to risk-oriented pairwise coverage. It must not produce a full Cartesian product.

Every adversarial scenario must retain its `sourceControlId` and mutation ID so a failing attack can be explained as:

`safe control -> exact mutation -> production observation -> containment finding`.

## 7. Attack families and containment contracts

### A. Identity substitution

Attacks:

- wrong owner;
- wrong recipient;
- swapped intended/attempted recipient;
- unrelated recipient with otherwise valid grant fixture.

Containment:

- unrelated identities never gain authority;
- mixed owner/recipient tuples fail closed;
- no data projection or notification detail is emitted to the wrong recipient.

### B. Action escalation

Attacks:

- VIEW grant used for NOTIFY;
- VIEW grant used for BACKUP;
- VIEW grant used for EXPORT;
- NOTIFY grant used for VIEW;
- BACKUP grant used for VIEW;
- EXPORT grant used for VIEW;
- selected paired cases involving multiple narrow grants.

Containment:

- authority for one generic action never creates another action.

### C. Scope substitution

Attacks:

- category substitution;
- field substitution;
- purpose substitution;
- valid category plus invalid field;
- valid category/field plus invalid purpose.

Containment:

- category, field, and purpose boundaries remain containment boundaries.

### D. Temporal and historical replay

Attacks:

- before activation;
- at activation safe control;
- at exact expiry;
- immediately after expiry;
- immediately before revocation;
- at exact revocation;
- after revocation;
- resource before `dataFrom`;
- resource at `dataFrom`;
- resource at `dataUntil`;
- resource after `dataUntil`.

Containment:

- exact production boundary semantics from Phase 9 remain authoritative;
- replay never revives inactive or revoked authority.

### E. Composed-grant confusion

Attacks:

- generic grant for recipient A + relationship grant for recipient B;
- generic VIEW for correct recipient + wrong relationship category;
- relationship capability for correct recipient + missing generic action;
- independently valid grants that do not belong to one composed authorization tuple.

Containment:

- unrelated grants cannot be stitched together into authority.

### F. Relationship capability escalation

Attacks:

- view -> relationship intelligence;
- view -> playful;
- view -> intimacy;
- notify -> playful;
- notify -> intimacy;
- playful -> intimacy;
- one-direction intimacy authorization used as bilateral authority.

Containment:

- capabilities remain independent unless production explicitly requires composition.

### G. Visibility exfiltration

Attacks:

- private item projected as visible;
- engine-only item queried for raw value;
- abstract-shared item queried for raw value;
- fully-shared grant paired with a more restrictive item visibility;
- item/grant visibility mismatch intended to trick most-restrictive selection.

Containment:

- the effective visibility ceiling remains the production most-restrictive result;
- unauthorized raw values never appear.

### H. Notification leakage

Attacks:

- locked device + detailed mode;
- category-only mode with private detail fixture;
- generic mode with private detail fixture;
- playful notification without playful capability;
- intimacy notification without intimacy capability;
- playful-intimacy notification missing one capability;
- valid content capability without notify capability;
- wrong recipient notification grant.

Containment:

- suppression/redaction follows production pipeline;
- no attack can increase notification detail.

### I. Revocation and recipient-key replay

Attacks:

- revoked grant reused after revocation;
- stale key state referenced after rotation;
- repeated revocation execution against deterministic fixture state;
- notification-capable revoked grant attempting post-revocation notification;
- export-capable revoked grant attempting post-revocation export authority.

Containment:

- production revocation effect remains authoritative;
- key rotation occurs where production requires it;
- stale authorization cannot regain access;
- notification stop/export invalidation expectations remain observable where production exposes them.

Phase 11 does not invent cryptographic key invalidation semantics that the production API does not expose.

### J. Relay recipient binding

Attacks:

- decrypt envelope as wrong recipient;
- recipient substitution against otherwise valid envelope;
- deterministic tampering of authenticated envelope fields supported by production crypto test fixtures;
- stale recipient/key-envelope combination when observable through production APIs.

Containment:

- wrong-recipient decrypt is rejected;
- authenticated-data/envelope tampering is rejected by production crypto/transport behavior;
- successful safe-control decrypt remains a paired control.

Phase 11 does not claim resistance to side channels or cryptanalytic attacks outside these production interfaces.

## 8. Detector strategy

The Phase 11 detector evaluates minimal containment contracts against normalized production observations.

It may assert observable invariants such as:

- wrong recipient was not allowed;
- action escalation did not authorize;
- raw value was not exposed;
- private notification detail was redacted or suppressed;
- stale grant did not regain authority;
- wrong-recipient relay decrypt did not succeed.

It must not reproduce grant matching, relationship ranking, visibility selection, notification rendering, key-rotation decision trees, or cryptographic validation logic.

Detector self-tests may inject impossible observations to prove a hypothetical privacy breach becomes an S4 result. Production smoke never uses an injected observer.

## 9. Finding categories and severity

All confirmed privacy-boundary breaches are S4 release failures.

Stable categories:

- `identity_scope_escape`
- `action_escalation`
- `scope_escape`
- `temporal_replay_escape`
- `composed_gate_bypass`
- `relationship_capability_escalation`
- `visibility_exfiltration`
- `notification_privacy_violation`
- `revocation_escape`
- `stale_key_escape`
- `relay_recipient_bypass`
- `relay_integrity_violation`
- `malformed_input`
- `coverage_gap`

Safe production denials, correct redaction, correct suppression, correct key rotation, and correct relay rejection are passing evidence rather than findings.

## 10. Malformed input and fail-closed behavior

Invalid scenario schema, blank required IDs, non-UTC timestamps, unknown enum values, malformed payload shapes, impossible fixture references, and production-adapter parsing errors must become deterministic failing `malformed_input` results.

The smoke must not silently skip malformed attacks.

Unexpected production exceptions must be normalized into fail-closed evidence without embedding host-specific stack paths in canonical JSON.

## 11. Determinism

Canonical evidence must be byte-stable for the same code, validated fixtures, and seed.

Forbidden nondeterministic content includes:

- wall-clock timestamps;
- random UUIDs;
- host paths;
- temporary directory names;
- environment variables;
- process IDs;
- unordered map/set traversal;
- nondeterministic exception text.

All timestamps in normalized evidence are UTC ISO-8601.

Results sort by stable scenario ID and deterministic secondary keys.

## 12. Coverage gates

Production smoke fails if any mandatory dimension has zero coverage.

Mandatory positive coverage:

- all ten attack families A-J;
- safe controls and adversarial attacks;
- all generic permission actions: VIEW, NOTIFY, BACKUP, EXPORT;
- category, field, and purpose scope attacks;
- activation, expiry, revocation, and data-window boundaries;
- relationship view, notify, relationshipIntelligence, playful, and intimacy capabilities where applicable;
- private, engineOnly, abstractShared, and fullyShared visibility contexts;
- generic, categoryOnly, and detailedWhenUnlocked notification privacy modes;
- recipient-key/revocation surface;
- relay-recipient/integrity surface;
- Phase 8 hard-gate reuse;
- Phase 9 permission-flow reuse;
- Phase 10 relationship-privacy surface reuse where applicable.

Coverage counts alone do not establish success. Every evaluated attack must also satisfy its containment contract.

## 13. Production adapter layer

Create a narrow `ProductionPrivacyAttackObserver` inside the simulation-domain Phase 11 implementation.

It maps canonical fixture payloads to production types, invokes production engines, and normalizes observations.

It does not independently decide authorization.

Where Phase 9 already has stable fixture/parser helpers, Phase 11 should reuse or extract focused shared helpers rather than duplicate large parsing blocks. Any extraction must preserve Phase 9 behavior and tests.

Production packages remain unchanged unless a real defect is discovered.

## 14. Canonical scenario strategy

The canonical smoke corpus combines:

- safe controls;
- single-axis attacks;
- selected pairwise attacks where composition is itself the privacy risk;
- exact temporal-boundary controls;
- malformed fail-closed controls;
- deliberate detector self-tests outside production smoke.

Examples:

- correct owner + wrong recipient + otherwise valid VIEW grant;
- correct VIEW grant mutated to EXPORT request;
- correct category with wrong purpose;
- revoked grant replayed exactly at `revokedAt`;
- generic grant for partner A composed with relationship grant for partner B;
- engine-only context paired with fully-shared grant;
- detailed notification on locked device;
- intimacy notification with notify but without intimacy;
- post-revocation stale recipient key state;
- relay envelope decrypted using wrong recipient ID.

The matrix is risk-oriented, not exhaustive.

## 15. Smoke command and evidence

Add:

`packages/simulation_domain/bin/privacy_attack_smoke.dart`

Canonical invocation:

```bash
cd packages/simulation_domain
dart run bin/privacy_attack_smoke.dart --seed=20260916
```

The command must:

- build the canonical safe-control/attack corpus;
- invoke production adapters only;
- validate mandatory coverage;
- print canonical JSON only;
- exit non-zero on any S4 breach, malformed-input failure, coverage gap, or unexpected fail-open behavior.

Expected output file in CI:

`privacy-attack-evidence.json`

Exact artifact name:

`simulation-privacy-attack-evidence`

## 16. CI integration

Extend `.github/workflows/simulation-lab.yml`.

Add `docs/SIMULATION_PRIVACY_ATTACK.md` to both pull-request and `main` push path filters.

After Phase 10 smoke, run:

`dart run bin/privacy_attack_smoke.dart --seed=20260916 > privacy-attack-evidence.json`

Upload exact artifact `simulation-privacy-attack-evidence` with `if-no-files-found: error` and the existing retention convention.

No feature branch is green merely because CI is queued or in progress. Exact feature SHA and exact merge SHA must each reach `completed/success` for both repository CI and Simulation Lab before Phase 11 closes.

## 17. Documentation

Add `docs/SIMULATION_PRIVACY_ATTACK.md` describing:

- purpose;
- production authority boundary;
- attack families;
- containment/detector strategy;
- deterministic generator;
- coverage gates;
- smoke command and artifact;
- evidence limitations;
- deferred Phase 16/21/22 scope;
- Issue #58 human-evidence boundary.

## 18. Tests

Create `packages/simulation_domain/test/privacy_attack_test.dart`.

Required test groups:

1. model validation and schema version;
2. JSON round-trip;
3. same-seed scenario generation stability;
4. byte-stable canonical report;
5. generator source-control linkage;
6. identity substitution containment;
7. action escalation containment;
8. scope substitution containment;
9. exact temporal/data-window boundaries;
10. composed-grant confusion containment;
11. relationship capability escalation containment;
12. visibility exfiltration containment;
13. notification leakage containment;
14. revocation/key replay containment;
15. relay-recipient/integrity containment using production-compatible deterministic crypto fixtures;
16. malformed input fail-closed;
17. detector self-tests proving every S4 category is detectable;
18. mandatory coverage-gap failure;
19. Phase 8/9 reuse assertions and Phase 10 privacy-surface reuse where applicable;
20. permuted input ordering still produces canonical result ordering.

Test-only observers may exist only for detector self-tests. Canonical smoke uses production adapters.

## 19. Expected implementation files

Primary files:

- `packages/simulation_domain/lib/src/privacy_attack.dart`
- `packages/simulation_domain/lib/simulation_domain.dart`
- `packages/simulation_domain/test/privacy_attack_test.dart`
- `packages/simulation_domain/bin/privacy_attack_smoke.dart`
- `.github/workflows/simulation-lab.yml`
- `docs/SIMULATION_PRIVACY_ATTACK.md`
- `docs/superpowers/plans/2026-09-16-privacy-attack-lab.md`

Production files are changed only if testing proves a production defect. Such changes require focused production regression tests and explicit review.

## 20. Completion gates

Phase 11 is complete only after all gates below pass in order:

1. design spec approved and committed;
2. implementation plan committed;
3. Issue #228 acceptance criteria backed by evidence;
4. local/container format verification passes;
5. analyzer has no new errors or warnings;
6. full `simulation_domain` tests pass;
7. privacy-attack smoke passes;
8. repeated same-seed smoke output is byte-identical;
9. canonical JSON parses and mandatory coverage is positive;
10. diff/hygiene/placeholder/forbidden-path checks pass;
11. exact feature HEAD repository CI is `completed/success`;
12. exact feature HEAD Simulation Lab is `completed/success`;
13. exact feature artifact exists, is named `simulation-privacy-attack-evidence`, and matches the feature HEAD evidence;
14. focused code review has no unresolved Critical or Important blocker;
15. Issue #58 is re-fetched and is `open/reopened` immediately before merge;
16. PR merges with expected-head/base guard;
17. `main` equals the exact merge SHA and merge tree contains the verified feature tree;
18. exact merge SHA repository CI is `completed/success`;
19. exact merge SHA Simulation Lab is `completed/success`;
20. post-merge artifact is downloaded and canonical evidence is independently verified;
21. Issue #228 checklist is updated with completion evidence and closed `completed`;
22. Issue #58 is re-fetched and remains `open/reopened`;
23. only then may Phase 11 be declared complete.

Queued, pending, or in-progress workflow state never counts as green.

## 21. Human-evidence boundary

Phase 11 is pre-human synthetic engineering validation.

It does not establish real-world privacy safety, clinical safety, clinical efficacy, participant comprehension, or usability.

Issue #58 remains the real Patient + Doctor human usability blocker. Phase 11 must never close it, mark its TODO complete, or describe synthetic attack evidence as human participant evidence.
