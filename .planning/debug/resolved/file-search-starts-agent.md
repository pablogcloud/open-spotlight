---
status: resolved
trigger: "i tried searching for a file and instead of searching for it the llm took it as a command instruction and it started executing a task"
created: 2026-07-18
updated: 2026-07-18
---

## Symptoms

- Expected behavior: Typing a filename and pressing Return opens the selected local result, or does nothing if no local result is selected.
- Actual behavior: When local search did not surface a result, the Ask-provider fallback was selected and Return started an LLM task.
- Error messages: None reported.
- Timeline: Reproduced after unified normal-search suggestions were added.
- Reproduction: Type a filename that produces only the Ask-provider row, then press Return.

## Current Focus

- hypothesis: Confirmed. Ordinary Return and explicit AI submission shared an unsafe fallback path, including AI history rows whose kind was recent but whose action was ask.
- test: Assert zero provider starts for Return with no suggestion, an Ask-provider suggestion, or a recent Ask action selected; assert explicit provider submission still starts exactly once.
- expecting: All safety assertions pass after action-based routing is enforced.
- next_action: Resolved and packaged.
- reasoning_checkpoint: Provider-start safety is now defined by the suggestion action rather than its presentation kind.
- tdd_checkpoint: Red harness reproduced both Ask fallback and AI-history failures; green harness and strict Swift test typecheck pass.

## Evidence

- timestamp: 2026-07-18T23:35:00-05:00
  observation: LauncherViewModel.submit falls through to submitToProvider when there is no selected suggestion.
- timestamp: 2026-07-18T23:35:00-05:00
  observation: LauncherViewModel.activateSelectedSuggestion executes the selected Ask-provider suggestion.
- timestamp: 2026-07-18T23:35:00-05:00
  observation: scheduleSuggestions defaults selection to index 0, including when Ask-provider is the only result.
- timestamp: 2026-07-18T23:20:00-05:00
  observation: Isolated harness failed with Return on Ask fallback started the provider before the fix.
- timestamp: 2026-07-18T23:24:00-05:00
  observation: Adversarial review found recent history rows use kind recent with action ask, bypassing a kind-only guard.
- timestamp: 2026-07-18T23:25:00-05:00
  observation: Isolated harness failed with Return on AI history started the provider before action-based hardening.
- timestamp: 2026-07-18T23:27:00-05:00
  observation: Final harness passed with zero Return provider starts and one explicit Ask start; independent re-review returned PASS.

## Eliminated

- hypothesis: The provider CLI incorrectly classified a local search request.
  reason: The launcher invoked the provider before the provider could distinguish intent; this is a UI routing defect.

## Resolution

- root_cause: Plain Return fell through to provider submission when no local suggestion existed, and keyboard activation treated Ask actions as normal rows. A kind-only guard also missed recent-history Ask actions.
- fix: Plain Return only activates non-provider suggestion actions. Ask actions require Command-Return or a direct row click, are never default-selected, and display the Command-Return hint. Spotlight metadata search now uses home and application scopes with a larger result window.
- verification: Swift 6 strict-concurrency app compilation and XCTest source typecheck pass; isolated metadata/index/routing harness passes; signed arm64 app verifies; independent Grok re-review returned PASS.
- files_changed: OpenLauncher/UI/LauncherViewModel.swift, OpenLauncher/UI/LauncherView.swift, OpenLauncher/Search/LauncherSuggestion.swift, OpenLauncher/Search/SpotlightMetadataSuggestionSource.swift, OpenLauncherTests/LauncherViewModelTests.swift
