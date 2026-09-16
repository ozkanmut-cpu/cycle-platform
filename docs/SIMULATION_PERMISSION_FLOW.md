# Simulation Lab — Permissions & Information-Flow Lab

Phase 9 expands Cycle Simulation Lab with deterministic permission and information-flow scenarios. It is synthetic engineering evidence only and does not establish clinical efficacy, real-world safety, or human usability.

## Production authority

Simulation Lab does not implement a second permission system. Phase 9 invokes the production-domain engines directly:

- `PermissionEvaluator` for generic owner/recipient/action/category/field/purpose/time/data-window decisions.
- `PrivacySimulator` to cross-check deterministic generic permission batches.
- `SharePolicy` for independent VIEW / NOTIFY / BACKUP projections.
- `RelationshipPermissionFirewall` for relationship-purpose capabilities.
- `RelationshipAccessGate` for composed generic + relationship authorization.
- `RelationshipContextProjector` for visibility-restricted projections.

Production packages never depend on `simulation_domain`; the dependency direction remains one-way.

## Scenario strategy

The canonical matrix is risk-oriented rather than a full Cartesian product. It combines safe controls, explicit boundary cases, pairwise interactions, and adversarial escalation/leakage attempts.

The matrix covers actor isolation, default deny, all four generic permission actions, scope containment, grant validity, exact revocation, historical data windows, all relationship capabilities, composed VIEW/NOTIFY gates, and all relationship visibility levels.

## Hard information-flow contracts

Every observed contract breach is S4 and fails the run. Stable violation reason codes are:

- `actor_scope_escape`
- `default_deny_bypass`
- `action_escalation`
- `category_scope_escape`
- `field_scope_escape`
- `purpose_scope_escape`
- `grant_time_escape`
- `revocation_breach`
- `data_window_escape`
- `relationship_capability_escalation`
- `composed_gate_bypass`
- `private_data_exposed`
- `engine_only_data_exposed`
- `abstract_data_exposed`

Safe production denials and correctly redacted projections are passing evidence. Detector self-tests may inject impossible observations only to prove the S4 detector catches a hypothetical production contract breach; the production smoke never uses injected observers.

## Permission semantics exercised

VIEW, NOTIFY, BACKUP, and EXPORT are independent. A grant for one action must not authorize another. Category, field, and explicit purpose constraints are containment boundaries rather than hints.

Grant activation is inclusive at `validFrom`; `validUntil` is exclusive. Access at or after `revokedAt` is denied. Historical resource bounds preserve the production `dataFrom` / `dataUntil` semantics, including exact-boundary controls.

Generic permission never implies `relationshipIntelligence`, `playful`, or `intimacy`. Relationship authorization cannot bypass generic VIEW/NOTIFY when a composed flow requires both gates.

Relationship visibility is an information-flow ceiling. Private, engine-only, and abstract-shared projections must not expose raw source values. Only an effective fully-shared projection may expose the raw value.

## Determinism and evidence

All simulation timestamps are UTC. Scenario IDs, result ordering, coverage maps, evidence maps, and JSON serialization are canonicalized. No wall-clock state participates in the matrix.

The same validated code, canonical matrix, and seed must produce byte-identical normalized JSON. The report always carries `syntheticEvidenceOnly: true`.

Malformed observer inputs fail closed as S4 `malformed_input` results and are counted; they are never skipped.

## Production smoke

Run from `packages/simulation_domain`:

```bash
dart pub get
dart run bin/permission_flow_smoke.dart --seed=20260916
```

The command builds the canonical Phase 9 matrix, executes production adapters only, and exits non-zero if any S4 contract fails. CI writes the normalized output to `permission-flow-evidence.json` and uploads artifact `simulation-permission-flow-evidence`.

Current coverage dimensions include scenario kind, generic action, relationship capability, effective visibility, temporal/data boundary, escalation-attempt count, and leakage-attempt count. Coverage requirements are tested so accidental matrix shrinkage fails before evidence publication.

## Relationship to Phase 8

Phase 8 remains the reusable hard-safety gate layer. Phase 9 expands permission and information-flow breadth around those gates; it does not replace the Phase 8 revocation or other safety contracts.

## Deferred scope

Phase 9 intentionally does not absorb later labs:

- Phase 10: broader relationship-behavior scenarios.
- Phase 11: adversarial privacy-attack generation.
- Phase 16: wrong-patient clinical-safety breadth.
- Phase 21: AI red-team breadth.
- Phase 22: Clinical + Playful collision breadth.

Later phases should reuse Phase 9 permission-flow primitives rather than creating parallel authorization policy.

## Human-evidence boundary

Issue #58 remains the real Patient + Doctor usability blocker. Permission-flow simulation, synthetic personas, automated journeys, CI evidence, and developer testing do not count as human usability validation and must never close #58.
