# Cycle Platform TODO

Legend: 🔴 V1 blocker · 🟠 V1 strong target · 🟢 polish/non-blocking

## 0 — Bootstrap
- [ ] 🔴 Flutter monorepo/workspace
- [ ] 🔴 CI: format, analyze, test
- [ ] 🔴 Architecture Decision Records
- [ ] 🔴 Threat model
- [ ] 🔴 Clinical/regulatory feature classification

## 1 — Canonical domain
- [ ] 🔴 HealthEvent
- [ ] 🔴 Observation/value/unit model
- [ ] 🔴 Episode model
- [ ] 🔴 Provenance
- [ ] 🔴 YES/NO/UNKNOWN/NOT_RECORDED/NOT_APPLICABLE semantics
- [ ] 🔴 temporal metadata + knowledge time
- [ ] 🔴 immutable identifiers and schema versioning

## 2 — Local security
- [ ] 🔴 encrypted SQLite
- [ ] 🔴 attachment vault
- [ ] 🔴 raw sensor vault
- [ ] 🔴 Android Keystore
- [ ] 🔴 iOS Keychain
- [ ] 🔴 key hierarchy and envelopes
- [ ] 🔴 append-only audit log
- [ ] 🔴 cryptographic erase path

## 3 — Patient core
- [ ] 🔴 Patient app shell
- [ ] 🔴 Today
- [ ] 🔴 Quick Log
- [ ] 🔴 Timeline/calendar
- [ ] 🔴 simple-first progressive disclosure
- [ ] 🔴 accessibility foundations

## 4 — Connected Health
- [ ] 🔴 Health Connect adapter
- [ ] 🔴 HealthKit adapter
- [ ] 🔴 reproductive/vitals/sleep/activity/body/nutrition mappings
- [ ] 🔴 normalization + unit conversion
- [ ] 🔴 source provenance
- [ ] 🔴 deduplication
- [ ] 🟠 sensor aggregation
- [ ] 🟠 Connected Health screen

## 5 — Intelligence foundations
- [ ] 🔴 Personal Baseline Engine
- [ ] 🔴 Temporal Query Engine
- [ ] 🔴 Missingness Intelligence
- [ ] 🔴 Information Value Engine
- [ ] 🔴 Uncertainty Graph
- [ ] 🟠 Contradiction Engine
- [ ] 🟠 Zero-Log Days
- [ ] 🟠 Health Data Time Machine

## 6 — Permissions, backup and sync
- [ ] 🔴 Permission Graph
- [ ] 🔴 field-level permissions
- [x] 🔴 VIEW/NOTIFY/BACKUP/EXPORT separation
- [ ] 🔴 purpose, date range and expiry
- [ ] 🟠 Privacy Simulator
- [ ] 🔴 .cyclevault backup
- [ ] 🔴 recovery material
- [x] 🔴 QR pairing and per-recipient keys
- [x] 🔴 opaque E2EE relay envelope
- [x] 🔴 blind backup
- [ ] 🟠 Recovery Drill

## 7 — Clinical domain
- [x] 🔴 Condition Pack framework
- [x] 🔴 guideline/rule versioning
- [x] 🔴 symptom-first routing
- [ ] 🟠 78-condition catalog definitions
- [ ] 🟠 body/pelvic pain map
- [ ] 🟠 bleeding intelligence

## 8 — Fertility, pregnancy and postpartum
- [x] 🔴 sexual activity model
- [x] 🔴 ConceptionExposureEvent
- [x] 🔴 BBT/LH/mucus support
- [x] 🔴 fertility confidence model
- [x] 🔴 PregnancyEpisode + dating
- [x] 🔴 pregnancy vitals/symptoms
- [x] 🔴 Pregnancy Safety Kernel
- [x] 🔴 outcomes and postpartum
- [ ] 🟠 kick counter and contraction timer

## 9 — Documents and interoperability
- [x] 🔴 document ingestion
- [x] 🔴 PDF parser / OCR fallback
- [x] 🔴 lab/imaging/pathology extraction
- [x] 🔴 human confirmation flow
- [x] 🔴 FHIR mappings
- [ ] 🟠 FHIR export bundle

## 10 — Clinical compression and AI
- [x] 🔴 Evidence Graph
- [x] 🔴 Clinical Compression
- [x] 🔴 Clinical Snapshot
- [ ] 🔴 AI Orchestrator
- [ ] 🔴 AI Context Firewall
- [ ] 🔴 Evidence/Safety validators
- [x] 🔴 AI audit
- [ ] 🟠 AI Learned About Me
- [ ] 🟠 Portable Clinical Package

## 11 — Doctor
- [x] 🔴 multi-patient Doctor shell
- [x] 🔴 What Changed/Matters/Missing/Uncertain/Conflicts/Open Loops
- [x] 🔴 natural-language structured record search
- [x] 🔴 Doctor Review Gate
- [x] 🟠 Clinical Reasoning Workspace
- [x] 🔴 Clinical Question Protocol
- [x] 🔴 Treatment Trial
- [ ] 🔴 result matching

## 12 — Partner
- [x] 🔴 Partner shell
- [x] 🔴 permission-aware read-only views
- [x] 🔴 private notification modes
- [x] 🔴 blind backup
- [ ] 🟠 support cards and Partner Signals

## 13 — Experience and validation
- [ ] 🔴 Tone Governor for serious clinical contexts
- [ ] 🟠 Playful Engine
- [ ] 🔴 localization TR/EN
- [ ] 🔴 app switcher privacy
- [ ] 🔴 biometrics/PIN
- [ ] 🔴 security/crypto review
- [ ] 🔴 clinical rule validation
- [ ] 🔴 AI red-team/evals
- [ ] 🔴 backup/recovery torture tests
- [ ] 🔴 sync conflict tests
- [ ] 🔴 patient and doctor usability testing
