---
phase: 9
status: in-progress
verified_at: 2026-07-19
---

# Phase 9 Verification - Source preview checkpoint

Phase 9 is **not complete** and the repository has not been published. This
checkpoint records only the locally reproducible source-preview foundation.
The user/legal/external gates in `09-PLAN.md` remain open, so this phase is not
eligible for its focused completion audit.

## Implemented evidence

- `7fd23f9` adds the source-preview README, privacy/security/contribution and
  governance documents, community templates, and a pinned GitHub Actions CI
  definition.
- `443ff69` normalizes Swift formatting across the tracked source and tests.
- The public copy labels the project pre-alpha, distinguishes implemented,
  partial and absent capabilities, explains provider prerequisites and local/
  remote data flow, and states that no supported or notarized binary exists.
- The repository has no configured remote and no outward publication action was
  taken.

## Local verification

The detached clean worktree at `7fd23f9` regenerated an identical Xcode project
and passed all 85 Swift tests. After the review corrections, the current tracked
tree passed the stricter final checkpoint commands:

```text
swift format lint --strict --recursive OpenLauncher OpenLauncherTests Package.swift
xcodegen generate
test -z "$(git status --porcelain --untracked-files=all -- OpenLauncher.xcodeproj)"
swift test
```

`swift test` passed 85 tests with 0 failures. YAML parsing passed for all files
under `.github`. The committed-tree scan found no personal home-directory or
macOS temporary-item paths, private-key markers, or common GitHub/AWS
provider-token prefixes. `git diff --check` also passed.

An independent Claude review initially returned `REVIEW BLOCKED` with four
concrete findings: an unrun CI build was described in the present tense,
formatting lint lacked strict failure behavior, untracked generated project
files could evade the check, and Xcode was not selected explicitly. The
checkpoint corrected all four by labelling CI unrun, using strict format lint,
checking complete project status, and initially selecting Xcode 16.4 on the
macOS 15 runner. The corrected delta passed the local checks and the narrowed
re-review returned `REVIEW PASS`. The reviewer also noted and this checkpoint
closed a non-blocking pipeline error-propagation gap in the project-cleanliness
step.

The first live GitHub run then exposed a stronger SDK requirement that the
review did not catch: Xcode 16.4 cannot compile the macOS 26 Liquid Glass symbols
even though their use is runtime-guarded. CI now selects Xcode 26.3 from the same
runner image. The next run compiled and executed all 85 tests, exposing a
CI-only scheduler race in the attachment-disclosure test: its fixed sequence of
`Task.yield()` calls could finish before the provider task started. The test now
waits on the fake runner's explicit start signal and passed ten repeated local
runs. The remote CI gate remains unverified until the corrected run passes.

## Verification limits

- The GitHub Actions workflow exists but cannot be claimed passing until it runs
  in the selected public/private GitHub repository.
- Native Debug and Release `xcodebuild` jobs are defined in CI but were not
  re-claimed locally; the existing host CoreSimulator/Xcode alignment blocker
  remains recorded in project state.
- `actionlint` is not installed on this machine, so only YAML parsing—not full
  GitHub Actions semantic linting—was run.
- The local token-pattern scan is a release hygiene check, not a complete secret
  or history audit.
- No open-source license is present. The source is not yet licensed for
  redistribution.

## Gate matrix

| Gate | Status | Evidence or blocker |
|---|---|---|
| Honest README, limitations and data flow | pass locally | `README.md`, `PRIVACY.md`, `.planning/STATE.md` |
| Community docs and templates | partial | Core files exist; final contacts, CODEOWNERS and Discussions/RFC ownership await repository decisions |
| Reproducible package tests and project generation | pass locally | Detached clean-worktree checks; 85/85 tests |
| GitHub CI | implemented-unverified | Workflow is pinned and committed; no remote run exists |
| License and contributor-rights model | blocked | Requires Pablo's approval |
| Product name/trademark treatment | blocked | Requires Pablo's decision and, if retained, qualified advice/permission |
| Provider-logo provenance and notices | blocked | Source/usage rights have not been approved or documented |
| GitHub owner, security contact and branch policy | blocked | Repository ownership has not been selected |
| Secret/history and asset-provenance audit | partial | Local tree scan passed; final history/assets audit depends on approved repository contents |
| Outward publication | blocked | Requires explicit approval; no publication was attempted |

## Completion rule

Resolve every blocked gate, run the committed workflow on GitHub, perform the
final license/asset/history/claim-link review, and then run the focused Phase 9
Grok audit. Only a decisive audit `PASS` plus those external checks may change
this record to verified.
