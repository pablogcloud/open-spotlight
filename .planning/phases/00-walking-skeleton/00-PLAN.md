---
phase: 0
mode: mvp
goal: Prove the three-provider native launcher loop end to end
verification: required
status: superseded
---

# Phase 0 Plan

> Historical prototype plan. It is retained as evidence of the original scope,
> but it cannot establish current completion. The active baseline plan is
> `../00-evidence-rebaseline/00-PLAN.md`.

## Task 1 - Project and provider core

Create the XcodeGen specification, native app target, test target, shared provider types, process runner, normalized event model, prompt builder, and fake-process test seams.

**Gate:** generated Xcode project builds and core unit tests pass.

## Task 2 - Three provider adapters

Implement Claude Code, Codex CLI, and Grok Build CLI argument construction, executable probing, version reporting, JSON/JSONL parsing, independent error reporting, and cancellation.

**Gate:** adapter conformance tests pass with fake fixtures; optional live probes return usable normalized output for each installed CLI.

## Task 3 - Native launcher experience

Implement global shortcut registration, launcher panel lifecycle, focused prompt composer, provider selector, streaming transcript, Stop/Retry actions, error/empty/completed states, and reduced-motion behavior using the approved design brief.

**Gate:** application builds and the panel can be driven entirely by keyboard.

## Task 4 - Attachment disclosure

Implement one-file selection, safe text extraction with size limits, payload summary, explicit confirmation, untrusted-content prompt wrapping, and source citation instruction.

**Gate:** prompt-construction tests prove file content is absent until confirmation and included exactly once afterward.

## Task 5 - Verification and correction

Run formatter/lint where available, unit tests, build, provider smoke probes, real-app launch, screenshots, accessibility/reduced-motion checks, and an adversarial code/design review. Correct all P0/P1 findings.

**Gate:** all automated gates pass and visual review records no unresolved P0/P1 defects.
