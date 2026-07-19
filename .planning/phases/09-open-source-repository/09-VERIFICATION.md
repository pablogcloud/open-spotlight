---
phase: 9
status: audit-pending
verified_at: 2026-07-19
---

# Phase 9 Verification - Public source preview checkpoint

The repository is now public, but Phase 9 is **not complete** until the focused
Grok audit passes and PR #1 merges through the protected `main` branch. This
checkpoint records the evidence available before that final audit.

## Implemented evidence

- `7fd23f9` adds the source-preview README, privacy/security/contribution and
  governance documents, community templates, and a pinned GitHub Actions CI
  definition.
- `443ff69` normalizes Swift formatting across the tracked source and tests.
- The public copy labels the project pre-alpha, distinguishes implemented,
  partial and absent capabilities, explains provider prerequisites and local/
  remote data flow, and states that no supported or notarized binary exists.
- The private staging repository was `pablogcloud/open-spotlight`. Draft PR #1
  remains the publication path into protected `main`.

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

## Publication boundary verification

- Pablo explicitly approved the `Open Spotlight` name, Apache-2.0 license,
  compatibility-identification provider-logo use, personal GitHub ownership,
  and outward publication.
- Commit `0dc63eb` corrected stale public claims, made GitHub private
  vulnerability reporting the primary security channel, and added hash-level
  provenance for each provider image. The original upstream logo download URLs
  were not retained; `NOTICE.md` states that limitation and claims no provider
  redistribution license.
- `gitleaks git --redact --no-banner .` scanned all 12 commits and reported no
  leaks. A broad directory scan reported 44 matches only inside ignored Xcode
  build attachments under `.build*`; no match was in the tracked tree or Git
  history. The earlier explicit path/token scans also remained clean.
- `actionlint -color`, strict Swift formatting, all 85 Swift tests, XcodeGen
  regeneration/project cleanliness, and `git diff --check` passed locally.
- GitHub Actions run `29706388376` passed strict formatting, all tests, project
  regeneration, and unsigned Debug and Release builds for `0dc63eb`.
- `https://github.com/pablogcloud/open-spotlight` is publicly reachable with
  HTTP 200. GitHub private vulnerability reporting, Dependabot security updates,
  secret scanning, and secret-scanning push protection are enabled.
- `main` requires the `verify` status check and a pull request, enforces linear
  history and conversation resolution, applies to administrators, and blocks
  force pushes and deletion. CodeQL default setup has been requested for Swift;
  its initial run must pass before the focused audit.

## Verification limits

- The GitHub Actions workflow passes in the public repository. The
  native builds are remote unsigned verification builds, not a signing,
  notarization or distribution claim.
- Local and GitHub secret scanning reduce risk but cannot prove that every
  possible secret pattern is absent.
- The provider-logo upstream download URLs were not retained. The owner-approved
  compatibility use, hashes, mark ownership, non-endorsement notice, and removal
  path are recorded; no upstream asset license is claimed.
- `labs@formm.mx` forwarding is not yet verified. GitHub private vulnerability
  reporting is the active primary channel, so the unverified address is not
  published as usable.

## Gate matrix

| Gate | Status | Evidence or blocker |
|---|---|---|
| Honest README, limitations and data flow | pass locally | `README.md`, `PRIVACY.md`, `.planning/STATE.md` |
| Community docs and templates | pass | Core files, CODEOWNERS, issue/PR templates, Discussions and maintainer ownership are configured |
| Reproducible package tests and project generation | pass locally | Detached clean-worktree checks; 85/85 tests |
| GitHub CI | pass | Run `29706388376` passed tests, regeneration and Debug/Release builds for the current head |
| License and contributor-rights model | pass | Apache-2.0 and its contribution terms approved; `LICENSE` committed |
| Product name/trademark treatment | owner decision recorded | `Open Spotlight` retained; non-affiliation notice committed; no legal clearance claim |
| Provider-logo provenance and notices | owner decision recorded | Compatibility-identification use approved and bounded in `NOTICE.md`; no provider license claimed |
| GitHub owner and repository policy | pass | Public `pablogcloud` repo, CODEOWNERS, Discussions, squash-only merge policy and protected `main` configured |
| Security reporting | pass | GitHub private vulnerability reporting is enabled as the primary channel; the unverified email fallback is labelled inactive |
| Secret/history and asset-provenance audit | pass with recorded limitation | Full history and tracked tree scan clean; logo hashes/ownership/use recorded, but upstream download URLs were not retained |
| Outward publication | pass | Explicitly approved; public repository returns HTTP 200 |
| Static analysis | pending | CodeQL default setup requested; initial Swift analysis must pass |
| Focused Grok audit | pending | Run only after CodeQL and all machine gates pass |

## Completion rule

Wait for the initial CodeQL analysis, then run the focused Phase 9 Grok audit.
Only a decisive audit `PASS`, a ready PR and a protected squash merge may change
this record to verified.
