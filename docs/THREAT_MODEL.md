# Cycle Platform Threat Model

## Protected assets

- reproductive and sexual-health records
- pregnancy and loss history
- clinical documents and results
- private notes
- partner/doctor permission state
- encryption keys and recovery material
- AI embeddings, summaries and derived inferences
- raw wearable/sensor data
- audit history

## Primary threat actors

- stolen or temporarily accessed device attacker
- malicious or over-curious partner/trusted person
- compromised clinician device
- compromised relay/notification provider
- malicious third-party SDK or supply-chain dependency
- local malware/rooted or jailbroken-device attacker
- accidental data leakage through notifications, screenshots, exports or backups
- unauthorized internal/service operator access where external infrastructure exists

## Core controls

- encrypted local database and file vaults
- platform keystore/keychain protected master key
- recipient-scoped E2EE keys
- key rotation after revocation
- app switcher privacy and discreet notifications
- biometric/PIN re-entry policies
- field/category/action-scoped Permission Graph
- no plaintext health payloads in relay/notification infrastructure
- append-only audit events
- least-data AI Context Firewall
- encrypted AI embeddings and caches
- cryptographic erase paths
- backup integrity verification and Recovery Drill

## High-risk abuse cases

### Partner coercion
No global one-tap share-all for sensitive categories. Sexual activity, pregnancy loss, STI and private-note data default to non-shared. Privacy Simulator shows exactly what a recipient can see.

### Relay compromise
Relay receives only opaque authenticated ciphertext plus minimum routing metadata. Relay compromise must not reveal health content or recipient decryption keys.

### Model overreach
Generative AI never bypasses permission evaluation, Clinical Safety Kernel or Doctor Review Gate. Critical safety decisions use validated deterministic rules.

### Data-source poisoning or duplicate ingestion
All imported records retain provenance, source chain and confidence. Deduplication never destroys raw source evidence.

### Device loss
Recovery depends on explicitly configured encrypted recovery material or blind backup; absence of recovery is surfaced clearly to the user.

## Open security work

- formal STRIDE/LINDDUN pass per subsystem
- cryptographic protocol review
- dependency/SBOM policy
- rooted/jailbroken device policy
- screenshot/screen-recording behavior by platform
- export package threat model
- secure deletion behavior by storage engine/filesystem
- relay metadata minimization review
- penetration test plan
