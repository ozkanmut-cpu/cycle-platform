# ADR-0001: Local-first storage and no mandatory patient account

Status: Accepted

## Context

Cycle stores highly sensitive reproductive, sexual and clinical information. Product differentiation depends on privacy that is architectural rather than policy-only.

## Decision

The Patient app will operate without a mandatory account. The canonical personal health record is stored locally in an encrypted vault. Remote transport, partner sharing, clinician sharing and backup operate on explicitly authorized encrypted payloads and do not redefine a server copy as the primary record.

## Consequences

- Device loss requires an explicit recovery strategy.
- Backup health and recovery drills are product requirements.
- Cross-device sharing requires recipient-scoped keys and E2EE envelopes.
- Cloud services must not require readable health payloads for core functionality.
- Features that cannot respect this boundary must be redesigned or isolated behind explicit opt-in.
