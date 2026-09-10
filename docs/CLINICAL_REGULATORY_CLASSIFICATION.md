# Clinical and Regulatory Feature Classification

Status: Baseline governance contract

This document classifies Cycle Platform features by intended product behavior and clinical risk so implementation, review, testing and release decisions use a consistent boundary. It is an engineering governance artifact, not a legal or jurisdiction-specific regulatory determination. Formal regulatory counsel/review remains required before claims, distribution or market-specific release decisions.

## Core principles

1. A feature is classified by intended use and user-facing claim, not only by implementation technique.
2. Generative AI, heuristics and deterministic rules do not independently diagnose, prescribe, change treatment or write unreviewed clinical conclusions into the canonical record.
3. Higher-risk clinical outputs require stronger evidence, validation, provenance and explicit human review.
4. Missing or uncertain information must remain explicit; the product must not convert absence of data into a clinical fact.
5. Any material change to intended use, claims, target population, clinical workflow or automated action requires reclassification before release.

## Classification levels

### C0 — Administrative / infrastructure

Examples:
- encrypted storage and backup
- account/pairing/permission management
- document transport and file organization
- notification routing without clinical interpretation

Requirements:
- security/privacy review
- functional and failure-mode testing
- no clinical claims

### C1 — Wellness / self-tracking

Examples:
- manual symptom or cycle logging
- timeline/calendar views
- non-clinical trends and summaries
- reminders and user-configured tracking utilities

Requirements:
- avoid diagnostic or treatment claims
- preserve provenance and uncertainty where derived data is shown
- usability/accessibility review

### C2 — Clinical information support

Examples:
- document parsing and normalization
- structured record search
- evidence-linked clinical snapshot/compression
- symptom-first routing to candidate information domains without diagnosis
- FHIR mapping/export

Requirements:
- evidence/provenance traceability
- explicit uncertainty and missing-data handling
- deterministic validation where applicable
- human-readable source access
- no autonomous diagnosis/prescribing/treatment change

### C3 — Clinician-reviewed decision support

Examples:
- Clinical Copilot reasoning workspace
- treatment-trial summaries
- clinical question protocols
- pregnancy safety rule results requiring review
- AI-generated clinical interpretations that may influence care

Requirements:
- Doctor Review Gate or equivalent explicit human review
- Evidence/Safety validation before presentation
- audit trail for inputs, model/rule version and output disposition
- validated rules/guidelines with version metadata
- no direct model-to-clinical-record write path
- release requires clinical validation appropriate to the intended claim

### C4 — Autonomous high-risk clinical action

Examples:
- autonomous diagnosis
- autonomous prescribing
- autonomous treatment initiation/change/cessation
- automatic emergency disposition presented as a definitive medical decision
- unreviewed AI write-back of clinical conclusions as authoritative record facts

Baseline Cycle policy: **not permitted**.

Any proposal to introduce a C4 capability requires a new architecture/regulatory decision, dedicated safety case, jurisdiction-specific regulatory assessment, clinical validation plan and explicit approval before implementation or release.

## Current feature map

| Feature area | Baseline class | Required boundary |
| --- | --- | --- |
| Patient logging / Today / Quick Log | C1 | tracking, not diagnosis |
| Connected Health ingestion | C1/C2 | source provenance + normalization; no diagnosis |
| Personal Baseline / Temporal / Missingness engines | C2 | evidence-linked, uncertainty explicit |
| Condition Packs / symptom-first routing | C2 | candidate routing only; no diagnosis |
| Pregnancy Safety Kernel | C3 | rule result + review/escalation disposition only |
| Clinical document extraction | C2 | source preservation + human confirmation |
| Clinical Snapshot / Compression / Evidence Graph | C2 | source-linked summaries |
| AI Orchestrator / Clinical Copilot | C3 | Context Firewall + Evidence/Safety validators + review gate |
| Doctor structured search | C2 | retrieval, not autonomous clinical judgment |
| Treatment Trial / Clinical Question Protocol | C3 | clinician-reviewed workflow |
| Partner views / notifications / blind backup | C0/C1 | permission-aware, no clinical interpretation |
| Any autonomous diagnosis/prescribing/treatment change | C4 | prohibited by baseline policy |

## Change-control checklist

Before merging or releasing a feature that can affect clinical interpretation, the owner must document:

- intended user and intended use
- user-facing claim or wording
- classification level (C0-C4)
- data sources and provenance
- uncertainty/missingness behavior
- whether deterministic clinical rules are involved and their version
- evidence validation requirements
- required human review gate
- audit requirements
- failure modes and safe fallback
- whether the change alters existing regulatory assumptions

If classification is ambiguous, default to the higher-risk class until reviewed.

## Release gates

- C0/C1: product/security/usability gates as applicable.
- C2: evidence/provenance and clinical-information validation gates.
- C3: C2 gates plus clinician review workflow, clinical validation and AI/rule safety evaluation as applicable.
- C4: blocked under the current architecture and product policy.

## Relationship to other governance artifacts

This classification must be read together with:

- `ARCHITECTURE.md`
- `docs/THREAT_MODEL.md`
- `docs/adr/0001-local-first-and-no-mandatory-account.md`
- AI Context Firewall / Evidence-Safety validator contracts
- Doctor Review Gate and Pregnancy Safety Kernel contracts

Future ADRs should reference this document when a decision changes an intended-use or clinical-risk boundary.
