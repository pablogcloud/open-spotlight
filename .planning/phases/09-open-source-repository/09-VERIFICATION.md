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
- The private staging repository is `pablogcloud/open-spotlight`. Draft PR #1
  contains the verified source-preview work; no public-visibility action was
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
runs. GitHub Actions run `29704664746` then passed strict formatting, all 85
tests, XcodeGen regeneration/project cleanliness, and unsigned Debug and Release
native builds at commit `d5439b9`.

## Verification limits

- The GitHub Actions workflow passes in the private staging repository. The
  native builds are remote unsigned verification builds, not a signing,
  notarization or distribution claim.
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
| GitHub CI | pass | Run `29704664746` passed tests, regeneration and Debug/Release builds |
| License and contributor-rights model | pass | Apache-2.0 and its contribution terms approved; `LICENSE` committed |
| Product name/trademark treatment | owner decision recorded | `Open Spotlight` retained; non-affiliation notice committed; no legal clearance claim |
| Provider-logo provenance and notices | owner decision recorded | Compatibility-identification use approved and bounded in `NOTICE.md`; no provider license claimed |
| GitHub owner and repository policy | partial | `pablogcloud` private repo, CODEOWNERS, Discussions and squash-only policy configured; private branch protection requires GitHub Pro or public visibility |
| Security reporting | partial | Vulnerability alerts and automated fixes enabled; `labs@formm.mx` forwarding is unverified and GitHub private vulnerability reporting is public-repository only |
| Secret/history and asset-provenance audit | partial | Local tree scan passed; final history/assets audit depends on approved repository contents |
| Outward publication | blocked | Requires explicit approval; no publication was attempted |

## Completion rule

Verify the security forwarding address, perform the final history/asset/
claim-link review, enable the public-only branch and vulnerability-reporting
controls at the publication boundary, and then run the focused Phase 9 Grok
audit. Only a decisive audit `PASS` plus those external checks may change this
record to verified.
