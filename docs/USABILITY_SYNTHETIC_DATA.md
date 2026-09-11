# Usability Synthetic Data Pack

Issue: #34
Dataset version: `usability-v1`

These records are fictional and exist only to exercise usability flows. They must never be represented as real patient records or clinical guidance.

## Patient P-001 — routine cycle logging

Purpose: basic Patient navigation, Today, Quick Log and timeline retrieval.

- age band: 25–34
- locale: tr-TR
- cycle history: 29–31 days, last three cycles recorded
- today: cycle day 12
- known: period start dates, moderate cramps on prior cycle day 1
- not recorded: cervical mucus today
- unknown: ovulation status
- expected user tasks: find today's state, log a symptom, locate a prior period event, distinguish unknown from not recorded

## Patient P-002 — incomplete/conflicting data

Purpose: Missing/Uncertain/Conflicts comprehension.

- age band: 35–44
- locale: en-GB
- two sources report differing sleep duration for the same night
- one imported resting-heart-rate observation has provenance but low confidence
- pregnancy status: UNKNOWN
- medication field: NOT_RECORDED
- symptom report: pelvic discomfort, severity recorded, laterality missing
- expected user tasks: identify what is known, missing and conflicting without inferring a diagnosis

## Patient P-003 — pregnancy safety review

Purpose: Doctor Review Gate, evidence/provenance and safety-language comprehension.

- fictional PregnancyEpisode with explicit dating provenance
- blood pressure observation with source metadata
- symptom entry that triggers review-required behavior in the test scenario
- AI-assisted summary must remain non-diagnostic and review-gated
- expected doctor tasks: find source evidence, recognize review requirement, explain that the system is not autonomously prescribing or changing treatment

## Patient P-004 — treatment trial/result matching

Purpose: Clinical Question / Treatment Trial / result matching.

- fictional trial window with start/end timestamps
- expected evidence type defined
- one matching result inside window
- one same-type result outside window
- one unrelated result
- expected doctor tasks: identify matched, missing/out-of-window results and inspect provenance

## Patient P-005 — privacy/lock flow

Purpose: Patient privacy comprehension.

- minimal fictional profile
- no sensitive free-text details
- expected user tasks: lock/unlock, observe privacy cover, explain what is hidden when app is backgrounded

## Data invariants

- All identifiers are synthetic (`P-001` etc.).
- No real names, dates of birth, addresses, phone numbers or medical record numbers.
- Missing values remain missing; do not fill them by inference.
- UNKNOWN and NOT_RECORDED remain distinct.
- Conflicting observations retain both source/provenance references.
- AI examples may summarize only evidence included in the fixture.
- No fixture may contain an autonomous diagnosis, prescription or treatment-change instruction.

## Session reset

Before each participant session:
1. reset to the same dataset version,
2. clear participant-created logs from the prior session,
3. verify fixture IDs and expected states,
4. record the study build SHA and dataset version in the session sheet.
