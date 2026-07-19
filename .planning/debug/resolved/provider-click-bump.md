---
status: resolved
trigger: "again when clicking the llm button it does nothing and the search bar has a bump now on the right for some reason"
created: 2026-07-18
updated: 2026-07-18
---

## Symptoms

- Expected: clicking the visible LLM control presents the Claude, Codex, and Grok switcher.
- Actual: clicking the control produces no visible response.
- Expected: the search glass remains a smooth capsule throughout provider reveal.
- Actual: a visible bump appears on the capsule's right edge.
- Reproduction: reveal the provider control from the magnifier, then click the provider logo.
- Timeline: regression reported after the latest provider-droplet motion change.
- Errors: none reported.

## Current Focus

- hypothesis: Confirmed stale runtime plus provider/search glass overlap and hover collapse during menu tracking.
- test: Four isolated interaction tests, 101 deterministic geometry samples, full unit suite, Release build, and cross-model critique.
- expecting: Provider popup routes three providers; menu tracking blocks collapse; provider never overlaps the search capsule after becoming visible.
- next_action: User can launch the newly packaged standalone Release app when ready.
- reasoning_checkpoint: Root causes and fixes verified without further desktop interaction.
- tdd_checkpoint: 52 tests pass; LauncherInteractionTests covers geometry, menu contents/routing, and tracking gate.

## Evidence

- 2026-07-18: PID 31727 was a stale DerivedData debug process started before the latest source and standalone bundle; it was terminated.
- 2026-07-18: The prior 20x34 provider seed overlapped the full-width search capsule inside GlassEffectContainer.
- 2026-07-18: The first zero-seed contact sheet still exposed mid-animation overlap, so the geometry was restaged around a non-overlapping seam.
- 2026-07-18: The final headless contact sheet and 101 sampled frames keep provider.minX >= search.maxX whenever provider area is nonzero.
- 2026-07-18: Standard NSPopUpButton menu model contains Claude, Codex, and Grok and routes selection.
- 2026-07-18: Full suite passes 52 tests; Release bundle builds and verifies with an ad-hoc signature.
- 2026-07-18: Independent tier-1-coder review reported no material defects.

## Eliminated

## Resolution

- root_cause: A stale live app process masked newer behavior; the provider glass overlapped the search capsule during reveal; hover exit could collapse the switcher while its menu tracked.
- fix: Replaced manual popup invocation with a stable transparent NSPopUpButton, blocked collapse during menu tracking, and restaged the droplet to grow from a seam without overlapping the capsule.
- verification: 52 tests pass, deterministic headless renderer passes its geometry preconditions, universal Release build and signature verify, and independent critique found no material defects.
- files_changed: OpenLauncher/UI/LauncherView.swift; OpenLauncherTests/LauncherInteractionTests.swift; OpenLauncher.xcodeproj/project.pbxproj
