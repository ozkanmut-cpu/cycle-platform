# Cycle Platform Architecture

## System boundary

Cycle Platform consists of three applications sharing one canonical health domain:

- Cycle Patient — source of truth for patient-generated health data.
- Cycle Partner — read-only, permission-scoped trusted-person client with optional blind backup.
- Cycle Doctor — multi-patient clinician client with evidence-linked Clinical Copilot.

## Architectural laws

1. Health data is local-first.
2. Raw data is not intelligence.
3. Intelligence is not evidence unless it can resolve back to source data.
4. AI is never authority; clinicians own clinical decisions.
5. Unknown, No, Not recorded and Not applicable are distinct states.
6. Permission is evaluated before model context is assembled.
7. Clinical safety rules are deterministic, versioned and independent of generative AI.
8. Partner and doctor access are recipient-specific and revocable.
9. Imported records preserve provenance and do not silently overwrite user or clinician records.
10. More passive/contextual data should reduce user logging burden, not increase it.

## Layer model

```text
Apps
├─ Patient
├─ Partner
└─ Doctor
   ↓
Experience Layer
   ↓
Permission / Privacy Policy
   ↓
Intelligence Layer
├─ Baseline Engine
├─ Temporal Engine
├─ Information Value Engine
├─ Uncertainty Graph
├─ Contradiction Engine
├─ Condition Packs
├─ Prediction
├─ Pregnancy
└─ Clinical Copilot
   ↓
Evidence / Safety Layer
├─ Evidence Graph
├─ Clinical Safety Kernel
└─ AI Review Gates
   ↓
Canonical Domain
├─ HealthEvent
├─ Observation
├─ Episode
├─ Clinical records
└─ Permission references
   ↓
Ingestion / Interoperability
├─ HealthKit
├─ Health Connect
├─ Wearables
├─ FHIR
├─ Documents
└─ Manual entry
   ↓
Encrypted Local Infrastructure
├─ Database
├─ Attachment Vault
├─ Raw Sensor Vault
├─ AI Store
├─ Audit Log
└─ Backup / Key envelopes
```

## Canonical event model

All health sources are normalized into a common model. HealthKit, Health Connect and vendor formats are adapters, never the canonical database schema.

A HealthEvent carries identity, subject, type, event/knowledge time, optional value/unit/severity/body location, cycle and pregnancy context, provenance, verification, confidence, privacy metadata and graph relationships.

## Temporal model

The platform distinguishes at least:

- event/observed time
- recorded time
- import time
- verification time
- valid time
- knowledge time

This enables the Health Data Time Machine: what was known at a historical moment versus what is known now about that moment.

## Graphs

### Health Graph

Connects events to episodes, sources, documents, conditions, clinicians and outcomes.

### Episode Graph

Groups longitudinal journeys such as pregnancy, IVF cycles, surgery, abnormal bleeding, PID, treatment, postpartum and contraception.

### Evidence Graph

Every serious analytic or AI claim must link to canonical observations and original sources.

### Uncertainty Graph

Tracks known, unknown, estimated, conflicting, stale, incomplete and low-confidence states.

## Data ingestion

```text
Source
→ adapter
→ schema validation
→ normalization
→ unit conversion
→ deduplication
→ provenance
→ confidence classification
→ canonical record
```

High-frequency sensor samples are stored in an encrypted Raw Sensor Vault and summarized into clinically useful features before entering the canonical graph.

## Permission graph

Permissions are policies, not simple toggles.

```text
owner
→ recipient
→ category / field
→ action: VIEW | NOTIFY | BACKUP | EXPORT
→ purpose
→ time range
→ expiry
```

Revocation triggers key-rotation hooks where required. Blind backup may store ciphertext that the backup holder cannot decrypt.

## AI architecture

AI is routed by task:

```text
Task
→ AI Orchestrator
→ Policy / Context Firewall
→ deterministic calculator | statistical model | time-series model | OCR | vision | local LLM | RAG | optional remote model
→ Evidence Validator
→ Safety Validator
→ user/doctor review gate where required
```

The least powerful and least privacy-invasive method that can solve the task should be preferred.

## Doctor architecture

Cycle Doctor is organized around clinical compression rather than raw event volume:

- What matters?
- What changed?
- What is missing?
- What is uncertain?
- What conflicts?
- What remains open?
- What evidence supports this?

AI-generated clinical notes, requests, referrals and explanations remain drafts until clinician approval.

## Partner architecture

Cycle Partner is read-only and permission-scoped. It supports support cards, user-selected Partner Signals, privacy-preserving notifications and blind encrypted backup. It never infers consent from cycle, fertility, libido or sexual activity data.

## Implementation strategy

V1 is built in dependency order, not feature-release order:

1. monorepo and quality gates
2. canonical domain
3. encrypted storage/key hierarchy/audit
4. Patient app core
5. HealthKit/Health Connect ingestion
6. provenance/deduplication/raw sensor vault
7. baseline/temporal/missingness/information-value engines
8. permission graph and backup/sync
9. Condition Pack framework
10. fertility, pregnancy and postpartum
11. document intelligence and FHIR
12. clinical compression/evidence/portable record
13. AI orchestration and clinical safety
14. Doctor app and Clinical Copilot
15. Partner app and blind backup
16. accessibility, privacy hardening, security/clinical/AI validation
