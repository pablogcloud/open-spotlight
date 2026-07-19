---
phase: 10
mode: mvp
goal: Distribute a signed, notarized, update-safe and supportable public beta
verification: required
---

# Phase 10 Plan - Signed public beta

## User gates before execution

- Approve Developer ID team, bundle identity, signing/notarization credentials,
  release-key ownership and recovery, update channel, privacy/support contacts,
  telemetry choice, supported architectures and final release action.

## Deliverables

1. Add final app icon, semantic version/build scheme, support matrix, minimal
   entitlements, Developer ID signing, Hardened Runtime, notarization and stapling.
2. Produce deterministic archive and DMG/ZIP packaging, install/uninstall steps,
   checksums, SBOM, third-party notices and changelog.
3. Implement signed Sparkle appcast/update verification, staged channels, rollback
   and signature-failure UX, or explicitly ship the first alpha without an
   updater rather than an unsigned one.
4. Add app/index schema migrations, downgrade/rollback policy, corrupted-index
   recovery, obsolete bundle cleanup and duplicate-hotkey prevention.
5. Add privacy controls for source removal, complete index deletion, trust reset
   and data-flow explanation. Diagnostics are opt-in and proven to omit prompts,
   filenames, paths, excerpts and credentials, or are absent.
6. Test clean-user-account and clean-Mac install, Gatekeeper launch, onboarding,
   provider auth, scoped index, file-aware citations, update/rollback and uninstall.
7. Protect release credentials/workflow and document support/security response.

## Acceptance gates

- `codesign --verify --deep --strict`, Gatekeeper assessment and stapler validation
  accept the downloaded artifact; notarization evidence matches it.
- A modified update/package is rejected and rollback preserves user settings or
  documents the migration boundary safely.
- Clean Mac completes the core journey with no old bundle/hotkey collision.
- Index deletion removes database, WAL/SHM, bookmarks, embeddings and caches.
- Diagnostics redaction fixtures contain none of the prohibited data classes.
- Published checksum/SBOM/version/capability matrix match the shipped artifact.
- Final non-Grok adversarial review has no unresolved release blocker.

## Verification

Run archive/sign/notarize/package/update/redaction and clean-Mac acceptance suites.
Record `10-VERIFICATION.md`, then run the focused Grok audit. Request explicit
release approval only after every gate is green.
