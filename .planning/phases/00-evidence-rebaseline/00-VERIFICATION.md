# Phase 0 verification - Evidence re-baseline

**Status:** local gates passed; blocked on Grok audit verdict
**Commit:** `3a243b2`

## Claims and gates

| Gate | Result | Evidence |
|---|---|---|
| G1 capability inventory | PASS | `STATE.md` labels every major surface absent, partial, or implemented-unverified; no row is marked verified. |
| G2 claim reconciliation | PASS | `PRODUCT-BRIEF.md`, `DESIGN.md`, `PROJECT.md`, requirements, and Settings now call the index an early text-only partial implementation. |
| G3 reproducible baseline | PASS | Root `Package.swift`; clean detached worktree regenerated the Xcode project and ran 83 tests with zero failures. |
| G4 current environment recorded | PASS | Toolchain, providers, bundle, database and signing state are recorded below from current commands. |
| G5 unsafe state recorded honestly | PASS | The pre-fix `/` preference, 2,932-document/45,697-chunk database, and 180%+ CPU behavior were recorded as unsafe prototype output, never as a completed index. |

## Current capability ledger

| Capability | Status | Current evidence boundary |
|---|---|---|
| Launcher panel, menu bar, shortcut, outside-click handling | implemented-unverified | Source plus interaction/unit tests; full visual UAT remains Phase 7. |
| Spotlight/Liquid Glass motion | partial | Isolated motion work exists; no current frame-level acceptance record. |
| Claude/Codex/Grok adapters | partial | Parser, invocation, cancellation, environment, and probe tests pass; current live prompt compatibility is not certified. |
| Provider selection/auth launch | partial | UI and tests exist; expired/missing/auth round trips need live UAT. |
| Metadata and indexed suggestions | partial | Local ranking/routing tests pass; quality benchmark and complete commands/calculations are absent. |
| Manually attached one-file disclosure | partial | Prompt construction and confirmation tests pass; multi-file retrieval disclosure is absent. |
| SQLite FTS and prototype embeddings | partial | Works for approved UTF-8 TXT/Markdown/JSON/CSV; not durable or benchmarked. |
| Safe approved-root policy | verified in Phase 1 only | See `01-VERIFICATION.md`; this does not imply production indexing. |
| Durable resume, FSEvents, PDF/Office, retrieval filters | absent | Phases 2-4. |
| Retrieved context, multi-file citations, extension SDK | absent | Phases 5 and 8. |
| Open-source/public distribution readiness | absent | Phases 9-10. |

## Commands and current environment

- `xcodegen generate`: passed with XcodeGen 2.44.1.
- `swift test` in repository: built the app module and executed 83 tests, zero failures.
- Clean detached worktree at commit `3a243b2`: `xcodegen generate` passed; `swift test` built and executed 83 tests, zero failures.
- Strict standalone compile: Swift 6, complete concurrency checking, macOS 15 target, arm64; passed and produced a runnable Mach-O.
- Xcode 26.6 / Swift 6.3.3. `xcodebuild` is externally blocked before compilation because system CoreSimulator 1051.54 is older than Xcode's required 1051.55; the process was interrupted after the repeatable stall.
- Claude Code 2.1.214, Codex CLI 0.144.1, Grok 0.2.103. Claude and Codex official auth-status probes exited 0; the Grok OAuth file was readable. No live model prompt was used for this baseline.
- Development bundle: `.build/Standalone/Open Spotlight.app`, bundle id `org.openspotlight.app`, arm64, ad-hoc signed. `codesign --verify --deep --strict` passes; Gatekeeper rejects it because Developer ID/notarization is Phase 10.
- Baseline source: 31 Swift files, 11 XCTest files, 72 tests before Phase 1; current Phase 1 checkpoint contains 83 tests.

## Real-app/database baseline

Before Phase 1 the persisted root was `/`; the active database grew to 2,932 documents and 45,697 chunks (292 MB), almost entirely outside the user's document scope, while the old app consumed roughly 163-186% CPU. The app was quit before migration. This was an unsafe prototype crawl, not successful indexing.

## Known limitations

- Xcode's GUI build service cannot complete until macOS/CoreSimulator and Xcode are version-aligned; SwiftPM and standalone Swift compilation are green.
- Visual, accessibility, launch-latency, and live provider response UAT are not Phase 0-verified.
- Provider logo rights, licensing, notarization, updater, and clean-Mac distribution remain later gates.

## Grok audit

- CLI: Grok 0.2.103
- Prompt bytes: 1,124
- Prompt SHA-256: `08a0e7b9e4179fddb609e29a85572ca2683176bb201fff4ebf2eaef55ca66da6`
- Exact CLI output:

  ```text
  Auditing Phase 0 claims against the stated evidence files only.
  Max turns reached
  Error: max turns reached
  ```

- Disposition: `NOT RUN`. The model returned no `PASS`, `FAIL`, or
  `INSUFFICIENT` verdict before the CLI's one-turn limit. Per the audit budget,
  this phase was not retried. Completion requires a later audit or Pablo's
  explicit waiver.
