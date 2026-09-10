# Cycle Platform TODO

Legend: 🔴 V1 blocker · 🟠 V1 strong target · 🟢 polish/non-blocking

## 0 — Bootstrap
- [x] 🔴 Flutter monorepo/workspace
- [x] 🔴 CI: format, analyze, test
- [x] 🔴 Architecture Decision Records
- [x] 🔴 Threat model
- [x] 🔴 Clinical/regulatory feature classification

## 1 — Canonical domain
- [x] 🔴 HealthEvent
- [x] 🔴 Observation/value/unit model
- [x] 🔴 Episode model
- [x] 🔴 Provenance
- [x] 🔴 YES/NO/UNKNOWN/NOT_RECORDED/NOT_APPLICABLE semantics
- [x] 🔴 temporal metadata + knowledge time
- [x] 🔴 immutable identifiers and schema versioning

## 2 — Local security
- [x] 🔴 encrypted SQLite
- [x] 🔴 attachment vault
- [x] 🔴 raw sensor vault
- [x] 🔴 Android Keystore
- [x] 🔴 iOS Keychain
- [x] 🔴 key hierarchy and envelopes
- [x] 🔴 append-only audit log
- [x] 🔴 cryptographic erase path

## 3 — Patient core
- [x] 🔴 Patient app shell
- [x] 🔴 Today
- [x] 🔴 Quick Log
- [x] 🔴 Timeline/calendar
- [x] 🔴 simple-first progressive disclosure
- [x] 🔴 accessibility foundations

## 4 — Connected Health
- [x] 🔴 Health Connect adapter
- [x] 🔴 HealthKit adapter
- [x] 🔴 reproductive/vitals/sleep/activity/body/nutrition mappings
- [x] 🔴 normalization + unit conversion
- [x] 🔴 source provenance
- [x] 🔴 deduplication
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
- [x] 🔴 AI Orchestrator
- [x] 🔴 AI Context Firewall
- [x] 🔴 Evidence/Safety validators
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
