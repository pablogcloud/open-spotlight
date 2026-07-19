# Open Spotlight

## Vision

Build a free, open-source, native macOS launcher that feels as immediate and familiar as Spotlight while reusing already authenticated Claude Code, Codex, and Grok Build CLI subscriptions.

## Current milestone

Re-baseline the existing launcher honestly, then make the experimental local index safe before durable indexing, extraction, file-aware AI, extensions, or public distribution are attempted. Current capability status lives in `STATE.md`; intended behavior is not evidence of completion.

## Product constraints

- Native Swift/AppKit shell with selective SwiftUI.
- Direct signed/notarized distribution; Mac App Store is not a Phase 0 target.
- Provider credentials remain owned and stored by each CLI.
- Provider failure is isolated; one unavailable CLI cannot disable the other two.
- No claim of operating-system sandboxing until a verified containment boundary exists.
- Local file context is manually attached in Phase 0 and fully disclosed before submission.
- Motion is purposeful, interruptible, performant, and honors Reduce Motion.

## Source of truth

The approved product direction and commercial guardrails live in `PRODUCT-BRIEF.md`.
