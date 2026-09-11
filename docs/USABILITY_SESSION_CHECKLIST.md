# Usability Session Checklist

Issue: #34

Use one copy per participant. This checklist prepares and records a human usability session; completing the checklist without a real participant does not count as usability validation.

## Session metadata

- participant code:
- participant group: Patient / Doctor
- study wave ID:
- git SHA:
- dataset version:
- app/platform/device:
- locale:
- moderator:
- date/time:

## Before session

- [ ] informed participation/consent process completed as applicable
- [ ] no production PHI loaded
- [ ] correct synthetic dataset reset
- [ ] correct immutable study build installed
- [ ] screen recording/notes policy confirmed
- [ ] moderator will not coach unless participant is blocked

## Patient tasks

For each task record: completed / completed with help / failed, time-on-task, backtracks, errors, comments.

- [ ] find today's relevant information
- [ ] log a common event through Quick Log
- [ ] find a prior event in timeline/calendar
- [ ] identify known vs missing vs uncertain information
- [ ] lock/unlock and explain privacy behavior
- [ ] explain whether the app is diagnosing or prescribing

## Doctor tasks

For each task record: completed / completed with help / failed, time-on-task, backtracks, errors, comments.

- [ ] open a patient and identify important recent changes
- [ ] identify missing/uncertain/conflicting information
- [ ] run a structured natural-language record query
- [ ] inspect AI-assisted output evidence/provenance
- [ ] use Doctor Review Gate correctly
- [ ] review Clinical Question/Treatment Trial and match results

## Safety/privacy observations

Mark any occurrence immediately and capture exact context.

- [ ] participant interprets AI as autonomous diagnosis
- [ ] participant interprets AI as autonomous prescribing
- [ ] participant interprets AI as autonomously changing treatment
- [ ] participant cannot distinguish evidence from AI-generated assistance
- [ ] participant exposes or misunderstands privacy-sensitive information
- [ ] participant misses a review-required state

Any checked item above is at least a high-severity finding until reviewed.

## Post-task rating

After each task capture:
- perceived ease: 1–5
- confidence: 1–5
- what was confusing?
- what did participant expect to happen?

## Finding severity

- Blocker: prevents safe/core completion or creates critical safety/privacy misunderstanding.
- High: major task failure, unsafe misunderstanding, or repeated severe confusion.
- Medium: recoverable friction or comprehension problem that materially slows the task.
- Low: cosmetic/minor friction with no meaningful task or safety impact.

## Session close

- [ ] all task outcomes recorded
- [ ] blocker/high findings identified
- [ ] notes anonymized
- [ ] recordings/attachments follow study data policy
- [ ] participant-created test data removed or reset

## Retest rule

A blocker/high finding affecting safety, privacy or core task completion must be fixed or explicitly accepted with rationale. Changed flows require a human retest before Issue #34 can close.
