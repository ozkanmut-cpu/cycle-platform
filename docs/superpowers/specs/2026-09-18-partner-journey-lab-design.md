# Phase 13 — Partner Journey Lab Design

Date: 2026-09-18
Status: approved architecture, pending written-spec review
Issue: #232
Branch: `phase-13-partner-journey-lab`
Base main SHA: `57ed8d8f1d9c6d33645696a9778f512607a86ffc`

## 1. Goal

Phase 13 adds a deterministic Partner Journey Lab to Cycle Simulation Lab.

The lab executes scripted synthetic journeys against the real Flutter Partner application and emits canonical machine-readable evidence describing whether critical Partner pairing, navigation, sharing, notification-privacy, and revocation journeys remain safe, reachable, recoverable, and consistent with the production relationship engines.

The lab is not a second Partner application, a copied sharing-policy engine, a camera simulator, a relay simulator, or human usability research. The Flutter Partner widgets and the production implementations in `cycle_sharing` and `cycle_permissions` remain authoritative.

All Phase 13 evidence is synthetic/pre-human engineering evidence only. It must contain `"syntheticEvidenceOnly": true`, must not close Issues #34 or #58, and must not mark the human-usability TODO complete.

## 2. Existing production authority reused

Phase 13 exercises these existing production surfaces and engines directly:

- `CyclePartnerApp`;
- `PartnerHomePage`;
- the Now, Us, Surprise, and Shared Health tabs;
- `PairingQrCodec` and `PairingInvitation`;
- `PartnerExperienceCoordinator`;
- `RelationshipHomeOrchestrator`;
- `RelationshipPermissionFirewall`;
- `RelationshipNotificationPipeline`;
- `SharingRevocationCoordinator`;
- `RecipientKeyRegistry`;
- `PermissionGrant` and `RelationshipCategoryGrant` lifecycle and scope;
- production empty-state, card-visibility, and notification-redaction behavior.

Phase 10 already validates the production relationship engines directly in pure Dart. Phase 13 does not duplicate those decision trees. It validates that production decisions reach the real Partner Flutter surface without scope widening, raw-value leakage, invented fallback content, or stale post-revocation display.

## 3. Non-goals

Phase 13 does not implement:

- camera or device QR scanning;
- relay or backend transport;
- secure-storage persistence;
- OS push or background notification delivery;
- blind-backup enrollment, restore, or recovery lifecycle;
- a new relationship, sharing, consent, or notification policy engine;
- screenshot-diff infrastructure;
- production PHI or real participant data;
- real Partner, Patient, or Doctor usability sessions;
- Phase 14 Doctor Journey Lab or any later phase.

The existing BACKUP capability chip may remain visible as a capability label, but Phase 13 must not claim that a backup lifecycle was exercised.

If a journey exposes a production defect, the fix belongs in the authoritative Partner or sharing code and receives a focused regression test. The harness must not mask the defect with alternate test-only behavior.

## 4. Architecture

Phase 13 uses a UI-first production-boundary lab.

Each canonical journey pumps the real `CyclePartnerApp`, interacts through `WidgetTester`, and controls only these external boundaries:

- pairing payload acquisition;
- deterministic UTC time;
- device locked/unlocked state;
- notification delivery capture;
- deterministic recipient-key-envelope generation;
- synthetic production model inputs and grants.

The harness never decides independently whether content is visible, whether a notification is allowed, how a notification is redacted, whether revocation rotates keys, or which relationship card should appear. It supplies validated inputs, invokes the UI, and observes production results.

Partner content is gated by a valid active paired session. An unpaired or revoked session may render navigation chrome and privacy-preserving empty/connect states, but must not render Partner cards or sensitive fixture markers.

## 5. App-internal Partner session seam

Add an app-internal `PartnerSessionController` and immutable `PartnerSessionState` under `apps/partner/lib/`. They are production application components, not journey models.

`CyclePartnerApp` and `PartnerHomePage` accept an optional `PartnerSessionController`. `PartnerHomePage` creates the production-default controller in `initState` when none is supplied, subscribes to it for rebuilds, and disposes it only when the page created it. An injected controller remains owned by its caller. Widget updates replace controller subscriptions without leaking listeners. Existing coordinator and model inputs remain constructor-injected, but their cards are rendered only while the controller reports a valid paired session.

`PartnerSessionState` records only application state needed by the UI:

- pairing status;
- validated `PairingInvitation` identity summary;
- selected `NotificationPrivacyMode`;
- device locked/unlocked state;
- latest allowed `PrivateNotification` preview;
- stable pairing/revocation error code;
- whether notifications are stopped after revocation.

`PartnerSessionController` receives:

- `PairingPayloadSource`;
- `PairingQrCodec`;
- `SharingRevocationCoordinator`;
- the matching active `PermissionGrant` used for revocation;
- `RecipientKeyRotator` backed by `RecipientKeyRegistry`;
- `RelationshipNotificationPipeline`;
- relationship notification request and grants supplied by the app composition root;
- `DateTime Function()` clock;
- notification preview sink.

Production defaults preserve wall-clock semantics with `DateTime.now`. The canonical harness injects `2026-09-18T09:00:00Z`.

`PairingPayloadSource` is the only QR acquisition seam. The production default for this phase is an unavailable source that returns no payload and leaves the app safely unpaired with a clear scanner-unavailable recovery message. Canonical tests inject encoded payloads. No production code contains canonical fixture payloads.

Pairing performs these steps in order:

1. acquire one payload from `PairingPayloadSource`;
2. decode it with the real `PairingQrCodec` at the injected current time;
3. require invitation owner and recipient IDs to match the configured Partner experience and revocation grant;
4. activate the paired session without creating or widening any permission grant;
5. rebuild the real Partner content from the existing coordinator inputs.

A pairing QR authenticates the intended relationship scope; it never grants VIEW, NOTIFY, PLAYFUL, INTIMACY, relationship-intelligence, BACKUP, or any other capability.

Malformed, expired, unsupported-version, cancelled, and actor-mismatched pairing attempts remain unpaired and expose a retry affordance. Raw codec/framework exception text is not displayed or written to canonical evidence.

Disconnect performs these steps in order:

1. call the real `SharingRevocationCoordinator` with the configured active `PermissionGrant`;
2. rotate the active recipient key through the registry-backed rotator;
3. require the returned result to report notifications stopped;
4. clear notification preview and validated pairing state;
5. return the Flutter UI to the unpaired state;
6. ensure no previous Partner card or sensitive fixture marker remains rendered.

The default key-envelope generator may use production randomness. The canonical harness injects stable envelope IDs. Canonical evidence records only the rotation count and version transition, not a production-random envelope ID.

## 6. Notification privacy preview

Add one Partner production presentation component for an in-app notification privacy preview. It receives the controller's production `PrivateNotification?` result and never formats relationship detail independently.

The Us sharing-controls surface retains the real `NotificationPrivacyMode` selector. When a paired session and a notification request are available, a preview action delegates to `RelationshipNotificationPipeline.present` with the active mode, device state, and production `RelationshipCategoryGrant` set.

Presentation rules remain owned by the production pipeline:

- generic mode shows only the generic redacted result;
- category-only mode shows the category result without detail;
- detailed-when-unlocked shows detail only while unlocked;
- detailed-when-unlocked falls back to generic while locked;
- missing NOTIFY or required content capability produces no notification preview.

The component displays only the returned title/body/redacted state. It does not manufacture a fallback notification when the pipeline returns `null`.

This preview validates deterministic in-app presentation only. It is not evidence for OS push delivery, background execution, notification permissions, or device lock-screen rendering.

## 7. Test-infrastructure model

Journey and evidence types live under `apps/partner/test/support/` and are never exported from the Partner production package.

### `PartnerJourneyFamily`

Stable values:

- `pairingLifecycle`;
- `partnerHomeNavigation`;
- `permissionScopedVisibility`;
- `notificationPrivacy`;
- `revocationDisconnect`;
- `relationshipSafetySurface`.

### `PartnerJourneyScenario`

Fields:

- schema version;
- stable journey ID;
- seed;
- fixed UTC virtual-now;
- synthetic fixture ID;
- locale;
- family;
- ordered action descriptors;
- required assertion IDs;
- expected recovery affordance IDs;
- risk tags.

The scenario describes UI actions and contract assertions. It does not contain a copied production permission or relationship decision tree.

### `PartnerJourneyObservation`

Normalized fields:

- surface/tab reached;
- pairing outcome code;
- retry affordance observed;
- visible assertion IDs;
- forbidden marker absence assertion IDs;
- card kind/reference/visibility summary;
- raw value visible/not visible;
- notification preview class and redacted flag;
- recipient-key version before/after revocation;
- notification-stop observed;
- paired/unpaired state after action;
- action count;
- navigation count;
- recovery count;
- stable driver-failure code.

Observations exclude host paths, temporary paths, framework exception strings, stack traces, object identities, production-random IDs, wall-clock values, process IDs, screenshot metadata, and unordered maps or sets.

### `PartnerJourneyFinding`

Fields:

- stable finding category;
- severity;
- journey ID;
- assertion ID;
- stable reason code;
- deterministic diagnostics.

### `PartnerJourneyCoverage`

Tracks:

- configured/evaluated/pass/fail/malformed counts;
- all six journey families;
- all mandatory coverage labels;
- positive and negative controls;
- canonical fixture IDs;
- fixed locale used by the smoke.

### `PartnerJourneyReport`

Contains:

- schema version;
- seed;
- fixed UTC provenance;
- stable sorted journey results;
- coverage;
- soft metrics;
- pass/fail summary;
- `syntheticEvidenceOnly: true`.

JSON field order and list order are canonical.

## 8. Canonical synthetic fixtures

Canonical seed: `20260918`.

Canonical virtual-now: `2026-09-18T09:00:00Z`.

Canonical locale: `en`.

Fixtures are synthetic and stable:

- `RP-001`: correctly scoped, fully shared, paired/unlocked positive control;
- `RP-002`: abstract-shared, paired/locked privacy control;
- `RP-005`: minimal/private sharing with active revocation grant and recipient key state.

Fixture builders may construct production `PairingInvitation`, `PermissionGrant`, `RelationshipCategoryGrant`, `PartnerExperienceInput`, notification request, and recipient-key objects. They must not calculate the expected production visibility, redaction, novelty ranking, or consent decision.

Sensitive negative-control markers are synthetic strings designed solely to detect leakage. They must never resemble real names, phone numbers, medical-record identifiers, addresses, or participant data.

## 9. Canonical journey families

### A. Pairing lifecycle

Journeys cover:

- a valid, correctly scoped, unexpired version-1 payload;
- malformed base64/JSON;
- expired invitation;
- unsupported invitation version;
- owner/recipient mismatch;
- cancellation/unavailable source;
- retry after one failed attempt using the real UI affordance.

Every invalid case remains unpaired and hides Partner content. Accepting malformed, expired, unsupported, or mismatched scope is S4.

### B. Partner Home navigation

Journeys navigate through the real bottom navigation to:

- Now;
- Us;
- Surprise;
- Shared Health.

The suite verifies production empty states, authorized cards, deterministic ordering, and the continued Read-only label. It verifies that an unpaired session exposes no Partner card values.

Phase 13 measures reachability and interaction cost. It does not claim that a human understood or preferred the navigation.

### C. Permission-scoped visibility

Journeys cover:

- fully shared content with permitted raw value;
- abstract-shared content without raw value;
- engine-only content absent from the Partner tree;
- private content absent from the Partner tree;
- wrong-recipient content absent;
- VIEW not implying NOTIFY, PLAYFUL, INTIMACY, relationship intelligence, or BACKUP;
- NOTIFY not implying VIEW.

Assertions inspect both expected labels and absence of synthetic raw markers from the rendered widget tree.

### D. Notification privacy

Journeys cover:

- generic;
- category-only;
- detailed-when-unlocked while unlocked;
- detailed-when-unlocked while locked;
- missing NOTIFY;
- missing PLAYFUL or INTIMACY content capability for the corresponding request kind.

Locked detail exposure, no-grant notification delivery, or capability widening is S4.

### E. Revocation and disconnect

The journey begins with a valid paired session, active permission grant, active recipient key, visible authorized content, and an allowed notification preview.

The user activates the real Disconnect control. The suite verifies:

- `SharingRevocationCoordinator` completed;
- the prior recipient key is revoked;
- the new recipient-key version is active;
- notifications are stopped;
- preview content is cleared;
- the session is unpaired;
- previously visible Partner content and sensitive markers are absent;
- retry/pairing affordance is restored.

Any retained revoked content, continued notification eligibility, or missing required key rotation is S4. A blocked disconnect interaction or missing recovery affordance is S3.

### F. Relationship safety surface

Journeys drive real `PartnerExperienceCoordinator` inputs into Now, Us, Surprise, and Shared Health and verify presentation boundaries only.

Required contracts:

- no invented suggestion when production returns none;
- no raw engine-only/private memory or health value;
- no scope-crossing card;
- no card or copy that treats cycle, fertility, libido, sexual, relationship, or health data as consent;
- no Partner write/edit affordance on the read-only app;
- safe permitted coordinator output may still appear when supplied by production.

Phase 13 does not reproduce Phase 10 engine calculations. It observes their production outputs through Flutter.

## 10. Severity and findings

`PartnerJourneySeverity` has exactly `none`, `s3`, and `s4`.

S4 finding categories:

- `unpaired_sensitive_content_exposed`;
- `locked_notification_detail_exposed`;
- `revoked_content_retained`;
- `notification_sent_without_permission`;
- `permission_scope_widened`;
- `pairing_invalid_payload_accepted`;
- `pairing_scope_mismatch_accepted`;
- `recipient_key_not_rotated`;
- `consent_inferred_from_sensitive_data`.

S3 finding categories:

- `core_journey_blocked`;
- `recovery_affordance_missing`;
- `partner_tab_unreachable`;
- `production_ui_mismatch`;
- `disconnect_incomplete` when no S4 exposure results;
- `notification_preview_mismatch` when no sensitive disclosure results.

Failing evidence categories:

- `malformed_input`;
- `coverage_gap`;
- `determinism_mismatch`.

Action count, navigation count, and recovery count are soft metrics. They never fail a journey without a separate S3/S4 contract violation.

## 11. Determinism and canonical replay

The same code, fixtures, seed, locale, and fixed UTC virtual-now must produce byte-identical canonical JSON.

The smoke uses one `testWidgets` body and exactly two complete fresh-suite invocations:

1. construct the first fresh harness, repositories, controller dependencies, and widget tree;
2. execute every canonical journey and produce normalized JSON bytes;
3. replace the widget tree with a neutral `SizedBox.shrink()` application and `pumpAndSettle`;
4. discard every mutable first-run object;
5. construct the second fresh harness, repositories, controller dependencies, and widget tree;
6. execute the same canonical journeys and produce normalized JSON bytes;
7. assert byte equality;
8. write the already-compared canonical bytes once to `partner-journey-evidence.json`.

No controller, payload queue, repository, key registry, sink, fixture object with mutable contents, or widget state is shared between invocations.

Results sort by journey ID. Actions, assertions, findings, and coverage labels sort by stable identifiers. Production-random key-envelope values are reduced to deterministic version-transition/count summaries.

## 12. Malformed input and fail-closed behavior

These inputs produce deterministic failing `malformed_input` evidence:

- blank or duplicate journey IDs;
- unsupported schema version;
- non-UTC virtual-now;
- unknown fixture ID;
- duplicate action/assertion IDs;
- action sequence that references a missing UI surface;
- missing required assertion IDs;
- unsupported family value in decoded fixture data.

The canonical runner never skips malformed journeys. Unexpected driver exceptions become stable `driver_failure` reason codes and never copy framework exception strings or paths into JSON.

Production `FormatException` and relationship-policy exception messages may be tested in focused unit tests, but canonical evidence stores stable normalized codes only.

## 13. Mandatory coverage labels

The report fails with `coverage_gap:<label>` for every missing label.

Mandatory labels:

- `family:pairingLifecycle`;
- `family:partnerHomeNavigation`;
- `family:permissionScopedVisibility`;
- `family:notificationPrivacy`;
- `family:revocationDisconnect`;
- `family:relationshipSafetySurface`;
- `pairing:valid`;
- `pairing:malformed`;
- `pairing:expired`;
- `pairing:unsupported-version`;
- `pairing:scope-mismatch`;
- `pairing:retry-recovery`;
- `home:unpaired-negative`;
- `home:now`;
- `home:us`;
- `home:surprise`;
- `home:shared-health`;
- `visibility:fully-shared`;
- `visibility:abstract-shared`;
- `visibility:engine-only-hidden`;
- `visibility:private-hidden`;
- `visibility:wrong-recipient-hidden`;
- `notification:generic`;
- `notification:category-only`;
- `notification:detailed-unlocked`;
- `notification:detailed-locked-redacted`;
- `notification:no-notify-suppressed`;
- `notification:content-capability-suppressed`;
- `revocation:key-rotation`;
- `revocation:notifications-stopped`;
- `revocation:content-cleared`;
- `revocation:unpaired`;
- `safety:no-consent-inference`;
- `safety:no-invented-fallback`;
- `safety:read-only`;
- `fixture:RP-001`;
- `fixture:RP-002`;
- `fixture:RP-005`;
- `control:positive`;
- `control:negative`.

Coverage counts do not establish success. Every journey must also satisfy its assertions and produce no unexpected S3/S4 finding.

## 14. Files and ownership boundaries

Production Partner changes are limited to focused app files:

- `apps/partner/lib/main.dart` for composition and UI delegation;
- `apps/partner/lib/partner_session.dart` for the app-internal controller/state and external-boundary interfaces;
- `apps/partner/lib/notification_privacy_preview.dart` for pipeline-result presentation.

Journey infrastructure lives only under:

- `apps/partner/test/support/partner_journey_models.dart`;
- `apps/partner/test/support/partner_journey_fixtures.dart`;
- `apps/partner/test/support/partner_journey_harness.dart`.

Focused and canonical tests live under `apps/partner/test/`. Exact test decomposition belongs to the implementation plan, but the plan must include focused controller, pairing, notification, revocation, widget, detector, coverage, malformed-input, and canonical smoke tests.

No Partner journey type is added to `packages/simulation_domain` or exported by `cycle_partner`.

## 15. CI and evidence artifact

Extend `.github/workflows/simulation-lab.yml` path triggers with:

- `apps/partner/**`;
- `packages/sharing/**`;
- `packages/permissions/**`;
- `docs/SIMULATION_PARTNER_JOURNEY.md`;
- `docs/superpowers/specs/2026-09-18-partner-journey-lab-design.md`;
- `docs/superpowers/plans/2026-09-18-partner-journey-lab.md`;
- `.github/workflows/simulation-lab.yml`.

Add a separate Flutter job named `partner-journey`. Do not add Partner Flutter tests to the pure-Dart `foundation` job.

The job uses Flutter stable and runs:

- Partner dependency resolution;
- Partner format check;
- Partner analysis;
- canonical Partner journey smoke;
- focused Partner regressions;
- evidence artifact upload.

Exact artifact name: `simulation-partner-journey-evidence`.

Exact evidence filename: `partner-journey-evidence.json`.

Artifact upload uses `if-no-files-found: error` and seven-day retention, matching the Patient journey pattern.

## 16. Documentation

Add `docs/SIMULATION_PARTNER_JOURNEY.md` describing:

- architecture;
- canonical journey families;
- production seams and authorities;
- severity model;
- mandatory coverage;
- determinism contract;
- evidence command and artifact;
- deferred device/transport scope;
- synthetic/human evidence boundary.

The document must not claim that users understand, trust, prefer, or can complete the Partner experience.

## 17. Verification and completion gates

Phase 13 is not complete until all of these are true on the exact feature SHA:

- focused Partner tests pass;
- full Partner test suite passes;
- format and analyze pass;
- canonical evidence is generated;
- fresh-suite byte equality passes;
- all mandatory coverage labels are present;
- no unexpected S3/S4 finding exists;
- evidence contains `"syntheticEvidenceOnly": true`;
- repository CI is `completed/success`;
- Simulation Lab `partner-journey` is `completed/success`;
- exact artifact and evidence filename are verified;
- code review gates are complete;
- Issue #232 is completed only after merge and post-merge verification;
- Issues #34 and #58 remain `open/reopened`;
- the human-usability TODO remains unchecked;
- Phase 14 has not started.

Queued or in-progress CI is never reported as green. Phase completion requires exact-SHA `completed/success` for the feature and merge commits, plus verified post-merge artifact bytes.

## 18. Evidence interpretation boundary

Phase 13 may conclude only that deterministic synthetic Partner engineering journeys satisfied their scripted contracts for the tested code, fixtures, seed, locale, and virtual time.

It may not conclude:

- Partner UX is validated;
- partners understand the interface;
- users trust the sharing model;
- human task completion passed;
- real relationship safety was validated;
- Patient, Partner, or Doctor usability validation is complete.

Real Patient and Doctor human usability validation remains governed by Issues #34 and #58. Synthetic Partner evidence cannot replace it.
