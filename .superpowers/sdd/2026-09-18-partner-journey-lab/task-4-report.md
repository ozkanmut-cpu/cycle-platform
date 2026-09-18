# Task 4 recovery report — deterministic fixtures and widget harness

Date: 2026-09-18
Branch: `phase-13-partner-journey-lab`
Task commit: `c3cbcc5` (`test(partner): add deterministic journey harness`)

## Files

- `apps/partner/test/support/partner_journey_fixtures.dart`
  - Defines the exact `PartnerJourneyFixture` contract.
  - Builds real production `PartnerExperienceInput`, relationship grants,
    permission grant, notification request, pairing payload, and recipient-key
    registry inputs for RP-001, RP-002, and RP-005.
  - Fixes seed `20260918`, UTC `2026-09-18T09:00:00Z`, locale `en`, and
    fixture-derived owner/recipient IDs.
- `apps/partner/test/support/partner_journey_harness.dart`
  - Provides the queued payload source, recording notification sink,
    deterministic envelope factory, and label-driven Flutter harness.
  - Owns mutable payload, key-registry, envelope, sink, and controller state.
  - Normalizes observations and uses the required widget-neutralization and
    controller-disposal cleanup order.
- `apps/partner/test/partner_journey_harness_test.dart`
  - Verifies stable fixture actors, grants, invitations, registry state, and
    synthetic markers.
  - Exercises real UI pairing/tab navigation, locked abstract visibility, and
    disconnect key rotation/content recovery.

## RED evidence

Local Flutter is not installed (`flutter test ...` exits 127 with
`flutter: command not found`). The approved GitHub connector was used against
feature PR #233's exact pre-Task-4 head SHA
`d23595ae702e4732da7a8aa148c08408165556e4`.

The terminal CI run `35320116858` failed in `Analyze Partner` as expected. The
failure was the missing fixture/harness imports and undefined fixture,
harness, and canonical-constant symbols in the RED test.

## GREEN evidence

The three files were published to PR #233 through the approved GitHub
connector. The first published attempt reached exact SHA
`4edd699e01148043e149e5831cd22860ba02e4ed` and run `35321817985` failed only
the formatter gate. After the formatter correction, exact SHA
`fefbb5545f4e4379a939f97131404fcb8acb7935` and run `35322038484` passed format
and analysis but exposed two focused test failures. The test-first fixes
addressed the RP-005 grant assertion and the required settle after
`ensureVisible` before tapping Disconnect.

The reconciled feature branch terminal SHA is
`7bb9008ad3af2eb7443428f31ff400837e43c157`. PR CI run `35322498229` completed
`success`; its format check, Partner analysis, Partner tests, and all other
workflow gates passed. No direct push was performed.

Local static verification completed with:

```text
git diff --cached --check  # passed before commit
```

## Commits

```text
c3cbcc5 test(partner): add deterministic journey harness
ac6f253 style(partner): format journey harness observation
f90d5e2 test(partner): stabilize journey harness controls
4652bdb docs(partner): record task 4 recovery
```

## Self-review

- Fixture values are synthetic, stable, UTC, and actor-scoped; no production
  participant data is present.
- The harness interacts through visible labels and reads rendered UI state; it
  does not reproduce sharing, notification, or revocation policy decisions.
- RP-001, RP-002, and RP-005 each receive fresh mutable dependencies.
- Cleanup neutralizes the widget tree, settles it, then disposes the
  controller exactly in the required order.
- Observation output contains normalized values only; framework exceptions,
  paths, object identities, and random envelope IDs are not serialized.
- No production files, issues, TODOs, or main branch were changed.
