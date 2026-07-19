---
phase: 5
mode: mvp
goal: Answer questions from local evidence without silently sending or executing it
verification: required
---

# Phase 5 Plan - File-aware AI answers and citations

## Deliverables

1. Replace single `ConfirmedFileContext` with a bounded multi-document context
   proposal containing source identity, exact excerpts, locations, byte/character
   counts, retrieval reason, provider and trust decision.
2. Separate search, open/reveal, and explicit Ask-AI actions. No empty-result or
   Return path may promote a normal search into provider execution.
3. Show the exact outgoing context and destination before submission; allow file
   and excerpt removal. Persist source-provider trust only through an explicit,
   revocable setting and never for denied/sensitive roots.
4. Wrap excerpts as untrusted evidence, delimit them from instructions, use the
   strongest tool-disabled/query-only provider mode available, and disclose all
   residual ambient access.
5. Map response citations to stable local source locations and implement Open,
   Reveal and Quick Look actions. Mark unsupported/unresolved citations visibly.
6. Keep the response panel alive across macOS permission/auth handoffs and make
   cancellation deterministic.

## Acceptance gates

- Prompt-capture tests prove no file text is present before confirmation and only
  selected excerpts are present afterward, exactly once.
- Typing a filename/topic and pressing Return never starts an agent unless the
  explicit Ask-AI action is selected.
- Adversarial instructions inside fixtures remain data and cannot alter the
  launcher-supplied instruction boundary in prompt snapshots.
- Every rendered citation resolves to the correct file/location or is labelled
  unresolved; Open/Reveal/Quick Look work in the built app.
- Clicking a permission/auth prompt does not dismiss or lose the pending answer.

## Verification

Run routing, prompt snapshot, injection, citation and lifecycle tests; capture an
end-to-end sanitized three-provider file question. Record `05-VERIFICATION.md`,
then run the bounded Grok audit.

