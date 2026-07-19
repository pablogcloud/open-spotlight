---
phase: 0
mode: mvp
goal: Replace prototype assumptions with a reproducible capability baseline
verification: required
---

# Phase 0 Plan - Evidence re-baseline

## Deliverables

1. Map every product claim to the source path, test, and real-app behavior that
   would prove it; label it `absent`, `partial`, `implemented-unverified`, or
   `verified`.
2. Reconcile `PRODUCT-BRIEF.md`, `DESIGN.md`, requirements, roadmap, settings
   copy, onboarding copy, and README-bound claims with the live code.
3. Record the actual build command, toolchain, supported architecture/macOS,
   installed provider versions, test count, bundle identifiers, active app
   locations, database schema/version, and index contents.
4. Bring the useful isolated lifecycle, suggestion, motion and index harnesses
   into a deterministic test location; remove personal data from fixtures.
5. Establish `NN-VERIFICATION.md` and public-claim matrix templates.

## Acceptance gates

- A clean generation/build/test command completes or every failure is recorded
  as a blocker; stale historical counts are not reused.
- Each current settings/onboarding capability has one ledger entry.
- No document says the index is both “not built” and complete.
- No `verified` row lacks a current command or real-app artifact.
- The current unsafe `/` index state is recorded without claiming completion.

## Verification

Run the complete local suite, inspect the installed app and database read-only,
exercise search/provider/index routes, write `00-VERIFICATION.md`, then run the
focused Grok audit in `../../GROK-AUDIT.md`.
