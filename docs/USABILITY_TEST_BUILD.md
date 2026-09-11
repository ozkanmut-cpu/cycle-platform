# Usability Test Build Standard

Issue: #34

This document defines the stable build used for Patient and Doctor human usability sessions. It is preparation only; it is not evidence that human usability testing has occurred.

## Build selection

- Use a single immutable git commit SHA for a study wave.
- Record the Patient and Doctor app versions, platform, OS version, device model, locale and build artifact identifiers.
- The selected commit must have a fully green main CI before being used in a session.
- Do not change app behavior during a study wave. If a blocker/high issue requires a fix, start a new build identifier and record the retest wave separately.

## Data policy

- Baseline sessions use synthetic records only.
- Do not use production PHI or participant medical records.
- Synthetic records must contain explicit known, unknown, not-recorded and conflicting data so uncertainty behavior can be tested.
- Any screenshots, recordings or notes must avoid unnecessary personal data.

## Patient test build

Required surfaces:
- Today
- Quick Log
- Timeline/calendar
- privacy cover
- biometrics/PIN
- known/missing/uncertain language

Required verification before a session:
- app launches cleanly from fresh install/state reset
- seed profile loads deterministically
- Quick Log changes appear in timeline/calendar
- privacy cover activates as expected
- lock/unlock path works
- no test data is mistaken for real clinical data

## Doctor test build

Required surfaces:
- multi-patient shell
- Clinical Snapshot
- What Changed / What Matters / Missing / Uncertain / Conflicts / Open Loops
- structured natural-language record search
- Doctor Review Gate
- Clinical Question / Treatment Trial / result matching

Required verification before a session:
- synthetic patients load deterministically
- evidence/provenance is visible for relevant outputs
- AI-assisted outputs remain review-gated
- no autonomous diagnosis, prescribing or treatment change is exposed

## Study build record

For every study wave record:
- study wave ID
- git SHA
- CI run number and URL
- Patient artifact/build identifier
- Doctor artifact/build identifier
- platform/device matrix
- seed dataset version
- locale
- date prepared
- known limitations

A study wave is valid only if these fields are complete and the referenced main CI is green.
