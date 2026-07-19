---
phase: 9
mode: mvp
goal: Publish an honest, reproducible and governable source-only pre-alpha
verification: required
depends_on: phase-1-and-user-gates
---

# Phase 9 Plan - Open-source repository and source preview

This phase may execute immediately after Phase 1. It does not depend on the
extension SDK or later public-beta features; unfinished capabilities must simply
remain labelled absent/partial and no binary is attached.

## User gates before execution

- Resolve whether to rename `Open Spotlight` or obtain qualified advice/permission.
- Approve license(s), DCO/CLA/contributor-rights model and trademark owner.
- Approve provider-logo sources, notices and non-endorsement treatment.
- Approve GitHub organization/repository ownership and the outward publish action.

## Deliverables

1. Scrub history/worktree for secrets, credentials, local databases, personal
   paths/content, generated apps, screenshots and temporary harnesses.
2. Add approved `LICENSE`, `NOTICE`, `README`, `SECURITY`, `CONTRIBUTING`,
   `CODE_OF_CONDUCT`, governance/maintainer, support, changelog/version and funding
   files. Document private vulnerability reporting and supported versions.
3. State real capabilities, limitations, provider prerequisites, local/remote
   data flow, build/test/run steps, architecture and pre-alpha status.
4. Add issue forms, PR template, Discussions/RFC path, CODEOWNERS and branch/
   release policy.
5. Add pinned CI for XcodeGen, Debug/Release build, complete tests, Swift 6 strict
   concurrency, format/lint policy, secret scanning, static analysis, dependency
   review and sanitized artifact retention.
6. Add asset provenance, third-party notices, dependency policy and reproducible
   clean-checkout instructions. Protect `main`; development remains PR-based.
7. Publish source only after Pablo's explicit approval; do not attach a binary or
   imply public support for unfinished capability rows.

## Acceptance gates

- A clean clone on the supported toolchain regenerates, builds and passes tests
  using only documented commands; CI reproduces it.
- Secret/personal-data, license and asset-provenance audits are clean.
- Every public claim links to a current verification record and limitation copy.
- GitHub community profile is complete and security contact works.
- The repository is still private/local until the explicit publication gate.

## Verification

Run clean-clone, CI-equivalent, secret/license/claim-link checks and review the
rendered public documentation. Record `09-VERIFICATION.md`, then run the focused
Grok audit before requesting publication approval.
