# Cycle Platform Security & Cryptography Review

Date: 2026-09-11
Scope: internal engineering review of the current V1 codebase
Status: review baseline; not an external audit, certification, or penetration test

## Executive summary

The reviewed implementation has a coherent fail-closed security baseline for V1: encrypted local storage, platform-backed secure key storage, AES-256-GCM authenticated encryption, recipient-scoped sharing keys, revocation/rotation flows, encrypted `.cyclevault` backups, recovery validation, app-switcher privacy, and deterministic security-related tests.

No critical or high-severity code defect was identified in the reviewed paths. The review does identify residual risks and follow-up work that should remain explicit before a production clinical release. In particular, platform secure-storage key material is application-readable after successful platform access rather than guaranteed hardware-non-exportable, relay metadata minimization has not been independently assessed, rooted/jailbroken-device policy is not yet formalized, and no independent penetration test has been performed.

## Scope and evidence

Reviewed design/code areas:

- `docs/THREAT_MODEL.md`
- `packages/crypto/lib/src/aes_gcm_authenticated_cipher.dart`
- `packages/crypto/lib/src/authenticated_cipher.dart`
- `packages/crypto/lib/src/key_deriver.dart`
- `packages/crypto/lib/src/key_hierarchy.dart`
- `packages/crypto/lib/src/key_envelope.dart`
- `packages/crypto/lib/src/backup_key_envelope.dart`
- `packages/crypto/lib/src/cryptographic_erase.dart`
- `packages/secure_key_store/lib/src/flutter_secure_key_store.dart`
- `packages/storage_sqlcipher/lib/src/sqlcipher_database.dart`
- encrypted attachment/raw-sensor vault implementation and tests
- sharing pairing, recipient-key, relay, revocation and permission-policy implementation/tests
- `.cyclevault` builder/codec/restorer/recovery-drill implementation and tests
- backup/recovery torture suite added in #26
- native security verification scripts and CI gates

CI baseline used for this review:

- Main CI #431 (`34549227433`) on `f77f5714b64fa2c25fe35cb05475c18e472685f7` passed format, analyzers, all package/app tests, iOS native integration, Patient APK build and artifact upload.

## Trust-boundary assessment

### Device boundary

Protected health data is intended to remain encrypted at rest. The SQLCipher database rejects an empty password and enables foreign keys and `secure_delete`. Attachments and raw-sensor data use encrypted file-vault boundaries rather than plaintext application storage.

Primary residual exposure is a compromised, rooted/jailbroken, or actively instrumented device after successful user/device unlock. The current model does not claim resistance to a fully compromised runtime.

### Platform key boundary

`FlutterSecureKeyStore` uses platform secure storage with Android RSA OAEP / AES-GCM options and iOS Keychain `unlocked_this_device`, with iCloud synchronization disabled. Backup migration is disabled for Android key material.

Key material stored by the app is nevertheless recoverable by the app after platform authorization. This is not the same as using a hardware-backed non-exportable asymmetric/private key or Secure Enclave/StrongBox operation where raw key bytes are never exposed to the application process.

### Sharing/relay boundary

The sharing model uses recipient-scoped keys, permission-aware views, revocation/rotation behavior and opaque encrypted relay envelopes. The relay is expected to handle ciphertext plus minimum routing metadata, not plaintext clinical content.

The cryptographic confidentiality boundary is therefore distinct from metadata privacy. Relay metadata minimization still requires a dedicated infrastructure review once the production relay schema is fixed.

### Backup/recovery boundary

`.cyclevault` uses encrypted payload entries plus manifest/entry integrity validation. Restoration is fail-closed for malformed/tampered data, unsupported schema versions and missing/wrong keys. The #26 torture suite verifies these failure classes and atomic caller-visible restore behavior.

## Cryptographic review

### Authenticated encryption

`AesGcmAuthenticatedCipher` uses AES-256-GCM through the `cryptography` package. It validates 32-byte keys and uses associated data when supplied. Encryption delegates nonce generation to the vetted library implementation rather than constructing deterministic/non-random nonces in application code.

Decryption rejects unexpected algorithm identifiers and authentication failures propagate as errors rather than returning unauthenticated plaintext.

Assessment: **PASS** for the reviewed V1 primitive usage.

### Key derivation and domain separation

`KeyDeriver` requires a master key of at least 256 bits and derives material using HMAC-SHA256 with explicit context/purpose separation. Empty salt maps to a zero-filled HKDF-style salt, which is acceptable when input key material is already high-entropy random key material; it must not be reused as a password KDF.

Assessment: **PASS with constraint** — only use this path for high-entropy key material, not human passwords/passphrases.

### Key rotation/revocation

Purpose-key and recipient-key models expose rotation and revocation semantics. Secure-key-store rotation persists the replacement and removes the old active key record.

Assessment: **PASS**, subject to application flows consistently invoking rotation after recipient revocation and not retaining decrypted keys in long-lived process caches.

### Cryptographic erase

The design relies on deletion/revocation of encryption keys so ciphertext becomes unrecoverable. This is stronger and more portable than assuming filesystem overwrite guarantees on flash storage.

Assessment: **PASS for cryptographic erase semantics**. Filesystem-level physical erasure is not claimed.

## Storage review

### SQLCipher

- Empty database passwords are rejected.
- SQLCipher-backed database package is used.
- `PRAGMA foreign_keys = ON` is applied.
- `PRAGMA secure_delete = ON` is applied.

Residual note: `secure_delete` is a defense-in-depth measure; flash translation layers and device snapshots may prevent physical overwrite guarantees. Confidentiality should continue to rely primarily on strong encryption/key destruction.

Assessment: **PASS**.

### File vaults

Attachment and raw-sensor data are separated into encrypted vault namespaces and are covered by tests.

Assessment: **PASS** for the reviewed application-layer boundary.

## Sharing and privacy review

Controls observed in the reviewed architecture include:

- per-recipient keys;
- QR pairing;
- VIEW/NOTIFY/BACKUP/EXPORT separation;
- restrictive permission conflict behavior;
- revocation/key rotation;
- opaque E2EE relay envelopes;
- blind backup;
- discreet/private notification modes;
- app-switcher privacy.

Assessment: **PASS for V1 code-level architecture**.

Residual infrastructure risks remain for production relay traffic analysis, account takeover, push-provider metadata and server-side operational logging. These cannot be closed through client code review alone.

## Backup/recovery review

The adversarial suite covers:

- malformed vault roots;
- manifest tampering;
- encrypted-entry tampering;
- missing manifest-declared entries;
- unsupported schema rejection before decryption;
- missing backup keys;
- wrong backup keys;
- multi-entry atomic failure from the caller perspective;
- deterministic Recovery Drill integrity/schema/key failure states.

Assessment: **PASS**.

## Findings

| ID | Severity | Finding | Impact | Status |
|---|---|---|---|---|
| SCR-01 | Medium | Secure-storage key bytes are application-readable after successful platform access; hardware-non-exportability is not guaranteed. | A runtime compromise after device/app authorization may expose raw key material. | Accepted V1 residual risk; evaluate StrongBox/Secure Enclave-backed wrapping/signing design for higher-assurance releases. |
| SCR-02 | Medium | Rooted/jailbroken-device behavior is not yet formalized. | Runtime instrumentation can defeat at-rest protections after unlock. | Open follow-up; define detection/response policy without presenting root detection as a security boundary. |
| SCR-03 | Medium | Production relay metadata minimization has not been independently reviewed. | Timing/routing/relationship metadata may reveal sensitive associations even when payloads remain encrypted. | Open follow-up once production relay schema/logging is fixed. |
| SCR-04 | Low | `KeyDeriver` uses a zero salt when none is supplied. | Safe for high-entropy master keys but unsafe if callers later treat it as a password KDF. | Documented constraint; do not use for password/passphrase derivation. |
| SCR-05 | Low | `secure_delete` cannot guarantee physical overwrite on flash/storage snapshots. | Deleted plaintext pages may theoretically persist below filesystem/database layers. | Accepted; cryptographic erase remains the primary deletion control. |
| SCR-06 | Medium | No independent penetration test or external cryptographic audit has been completed. | Implementation/integration defects may remain outside unit/integration-test coverage. | Required pre-production assurance activity; this internal review does not replace it. |

No critical/high finding requiring an immediate code change was identified in this review.

## Release constraints

The following statements must remain true unless a new review supersedes this document:

1. Never use `KeyDeriver` as a human-password KDF.
2. Never send plaintext health content through relay/notification infrastructure.
3. Never treat app-switcher privacy, biometrics, root detection, or `secure_delete` as substitutes for encryption.
4. Recipient revocation must invalidate future access and rotate recipient-scoped material as designed.
5. Backup restore must remain fail-closed; do not bypass manifest/integrity/schema/key checks for compatibility.
6. Any future cryptographic algorithm/nonce/key-storage change requires a new security review and deterministic migration tests.
7. External penetration testing and production-infrastructure review remain separate release-assurance activities.

## Review conclusion

The current codebase satisfies the internal V1 `security/crypto review` engineering gate, with the residual risks above explicitly accepted as follow-up work rather than silently treated as solved. This document does not certify regulatory compliance, production infrastructure, endpoint compromise resistance, or penetration-test readiness.
