# Simulation Privacy Attack Lab

Phase 11 validates privacy containment by generating deterministic adversarial mutations and exercising the production permission, sharing, relationship, revocation, key, notification, relay, and authenticated-encryption primitives. Simulation Lab does not implement a second authorization, visibility, notification, revocation, or cryptographic policy engine.

## Attack families

The canonical corpus covers ten production-authoritative families:

- **A — Identity substitution:** wrong owner and wrong recipient attempts.
- **B — Action escalation:** VIEW / NOTIFY / BACKUP / EXPORT capability substitution, including SharePolicy independence.
- **C — Scope substitution:** category, field, and purpose mismatch attacks.
- **D — Temporal replay:** activation, expiry, revocation, and historical data-window boundaries.
- **E — Composed-grant confusion:** generic and relationship gates must both authorize the same scoped operation.
- **F — Relationship capability escalation:** VIEW does not imply intelligence, playful, or intimacy authority.
- **G — Visibility exfiltration:** private, engine-only, and abstract-shared context cannot become raw exposure.
- **H — Notification leakage:** privacy mode, device lock state, and playful/intimacy content capabilities remain independent.
- **I — Revocation and key replay:** production revocation rotates recipient keys, stops notifications when applicable, invalidates export authority, and rejects stale-key reuse.
- **J — Relay recipient binding:** correct-recipient decrypt succeeds while wrong-recipient, associated-data tampering, and ciphertext tampering fail closed.

## Positive controls and detector limits

Every adversarial scenario is paired with a stable safe control. Positive controls prove that an otherwise valid operation still succeeds; attacks change one controlled privacy dimension wherever possible. The detector evaluates only minimal observable containment contracts such as allow/deny, project/no-project, raw/no-raw, notification emitted/redacted, key rotation/stale-key rejection, and relay decrypt/integrity rejection.

The detector does not predict production policy. Authorization, relationship visibility, notification redaction, revocation effects, key rotation, recipient binding, and AES-GCM authentication remain production responsibilities. Impossible observations used by detector self-tests exist only in tests and are never used by production smoke evidence.

## Async relay and crypto handling

Relay and AES-GCM paths are asynchronous. The Simulation Lab uses the production `SharingTransport` and `AesGcmAuthenticatedCipher` with deterministic fixture key material derived from the complete key-envelope ID. Random nonce, ciphertext, authentication tag, key bytes, and other secret material are never serialized into the evidence report; only normalized containment observations are recorded.

## Determinism and coverage

The same seed, code, and fixtures produce byte-identical normalized JSON evidence. Scenario and result ordering is canonical. Mandatory coverage requires all ten attack families plus action, scope, temporal, relationship capability, visibility, notification privacy, production-surface, and Phase 8/9/10 reuse dimensions. Missing required coverage produces an S4 `coverage_gap` result.
## Smoke and CI evidence

Run locally:

```bash
cd packages/simulation_domain
dart run bin/privacy_attack_smoke.dart --seed=20260916
```

GitHub Actions writes `privacy-attack-evidence.json` and uploads it using the exact artifact name:

`simulation-privacy-attack-evidence`

Evidence must be parseable canonical JSON with `passed=true`, `syntheticEvidenceOnly=true`, zero malformed-input failures, positive safe-control and adversarial counts, all ten families, and every mandatory coverage label.

## Deferred scope

Phase 11 does not absorb Phase 16 Wrong-Patient Safety, Phase 21 AI Red-Team expansion, Phase 22 Clinical + Playful Collision, general-purpose fuzzing, cryptographic algorithm breaking, timing side-channel research, or human journey/usability work.

## Human-evidence boundary

This phase produces synthetic adversarial privacy evidence only. It does **not** satisfy, replace, or close Issue #58, which requires real Patient + Doctor human usability validation and must remain open/reopened until that human evidence exists.
