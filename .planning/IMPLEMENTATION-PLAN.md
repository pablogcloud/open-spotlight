# Open Spotlight Public-MVP Implementation Plan

## Objective

Deliver an honest, native macOS public beta whose launcher remains useful without
AI, whose local index is scoped, resumable and resource-bounded, and whose file-
aware answers disclose and cite every local excerpt sent to Claude, Codex, or
Grok. Publish the source and binaries only after their separate release gates.

## Why this replaces the previous roadmap

The repository contains more than a walking skeleton, but several prototypes
were described as finished systems. In particular, the local index can store and
search limited text, yet rebuilds are destructive and non-resumable, whole-volume
roots are accepted, indexed results are not assembled into provider context, and
the repository is not ready for public distribution. This plan treats those as
explicit gaps rather than implied follow-up polish.

## Definitions

- **Implemented:** code exists, but its release behavior has not been proven.
- **Verified:** automated checks, real-app checks where relevant, and recorded
  evidence satisfy the phase gate.
- **Source preview:** public code labelled pre-alpha, with no supported binary.
- **Public beta:** signed/notarized binary with documented privacy and support
  boundaries.
- **Grok audit:** a focused read-only review of concise but complete evidence.
  It is a guard against unsupported claims, not a substitute for tests.

## Non-negotiable product boundaries

1. The default index never scans `/`, `/System`, `/Library`, `/private`, another
   volume root, hidden credentials, packages, caches, or dependency trees.
2. The last usable index remains searchable during rebuilds and after crashes.
3. Lexical search becomes useful before optional embeddings finish.
4. No retrieved text enters a provider request without disclosure and the
   applicable confirmation/trust decision.
5. Search intent never becomes an agent instruction merely because it has no
   local result. AI execution requires an explicit AI action.
6. Open Spotlight never reads or stores provider tokens.
7. Provider restrictions are described as best-effort unless an actual OS-level
   containment boundary is implemented and tested.
8. A capability is never marked complete from UI presence, a compilation pass,
   or a model assertion alone.

## Execution protocol for every phase

1. Create or update the phase requirement-to-test matrix.
2. Add a failing test or deterministic reproduction for each bug/capability.
3. Implement the smallest vertical slice that reaches the user-visible result.
4. Run focused tests while developing, then the complete test/build suite.
5. Exercise the built app for UI, lifecycle, permissions, provider, and release
   behavior that unit tests cannot prove.
6. Write `NN-VERIFICATION.md` with exact commands, outcomes, artifacts, residual
   risks, and capability-status changes.
7. Run the focused Grok audit from `GROK-AUDIT.md`. Do not loop automatically;
   retry after correcting a concrete release blocker or when Pablo asks.
8. Update `STATE.md` only from the verification record.

## Phase map

| Phase | Outcome | Depends on | Relative size |
|---|---|---|---|
| 0 | Truthful baseline and reproducible evidence | Existing code | Small |
| 1 | Unsafe indexing prevented; repo baseline controlled | 0 | Medium |
| 2 | Durable resumable index | 1 | Large |
| 3 | Incremental, throttled background indexing | 2 | Large |
| 4 | Useful formats and measurable hybrid retrieval | 3 | Large |
| 5 | Disclosed multi-file AI context and citations | 4 | Large |
| 6 | Three providers/auth flows hardened | 5 | Medium/Large |
| 7 | Launcher/search/settings/native-quality release gate | 6 | Large |
| 8 | One constrained extension format | 7 | Medium |
| 9 | Public source-preview repository | 1, naming/legal decisions | Medium |
| 10 | Signed/notarized public beta | 2-9 | Large |

## Cross-phase test assets

- Synthetic nested file tree with allowed, denied, hidden, package, credential,
  symlink, rename, delete, malformed, encrypted, and permission-denied cases.
- At least 10,000 generated metadata records for queue/crash/performance tests.
- Sanitized TXT, Markdown, PDF, DOCX, XLSX and PPTX fixtures with known text,
  dates, currencies, topics, and expected citations.
- Retrieval query set covering exact filename, fuzzy title, semantic topic,
  date range, type/root filters, and adversarial instructions inside documents.
- Sanitized streaming fixtures for supported Claude, Codex and Grok CLI versions.
- Lifecycle/UI harness covering shortcut, focus, outside click, provider menu,
  auth handoff, disclosure, stop/cancel, multi-display and Reduce Motion.

## Public-claim matrix required before release

For every README, website, onboarding, setting, and release-note claim, record:

| Claim | Capability | Verification file | Limitation copy | Owner |
|---|---|---|---|---|

CI fails when a public capability is marked `verified` without its verification
record or when product documents still describe a removed/stale boundary.

## User decision gates

Implementation can proceed without these decisions, but the named release cannot:

1. Rename the product or obtain appropriate advice/permission for using
   `Spotlight` in the product name.
2. Approve the core license, SDK license, DCO/CLA choice, and contributor policy.
3. Approve official provider-logo assets and their attribution/notice treatment.
4. Provide or approve Developer ID, notarization, update-signing, support-email,
   security-contact, and GitHub-organization ownership.
5. Explicitly authorize creating and making the GitHub repository public.

## Release gates

### Source-only pre-alpha

- Phases 0, 1 and 9 verified. Phase 9 may run immediately after Phase 1 and does
  not depend on the extension SDK or the downloadable-beta feature set.
- Naming/license/assets decision complete.
- Repository scrub and secret scan clean.
- CI builds and tests from a clean checkout.
- README capability matrix says `pre-alpha` and lists incomplete phases.
- No binary or unsupported file-aware/provider-compatibility promise.

### Public beta binary

- Phases 0 through 10 verified.
- Clean-user-account and clean-Mac install/update/uninstall tests pass.
- Index crash, scope, resource, and retrieval benchmarks pass.
- Provider compatibility matrix is current and limitations are visible.
- Privacy, security, accessibility, diagnostics and rollback gates pass.
- Final focused Grok audit and a non-Grok adversarial code review have no open
  release blockers.
