---
phase: 6
mode: mvp
goal: Make Claude, Codex and Grok compatibility explicit, isolated and recoverable
verification: required
---

# Phase 6 Plan - Provider and authentication hardening

## Deliverables

1. Build sanitized streaming/parser fixtures for supported CLI versions and a
   dated minimum/known-good/unsupported compatibility matrix.
2. Probe executable, version, authentication readiness and actual capability
   flags independently; never infer authentication from executable presence.
3. Give logged-out, missing, incompatible, quota and permission states distinct
   UI. Launch only official install/login flows and reprobe when control returns.
4. Preserve launcher/query/answer state while Terminal, browser, System Settings
   or a permission sheet has focus.
5. Maintain an allowlisted environment, stdin prompt transport, isolated working
   directory where possible, and documented hooks/memory/rules/tool/filesystem/
   network behavior for each provider. Never copy tokens into app storage.
6. Use tool-disabled/query-only flags only where the probed version supports
   them; expose residual capabilities instead of calling them sandboxed.
7. Cancel the whole process tree, bound output/time, normalize malformed streams,
   and isolate one provider's failure from the others.

## Acceptance gates

- Every sanitized fixture passes the shared adapter conformance suite.
- Unsupported versions/flags fail before submission with an actionable state.
- Auth handoff returns to the same pending launcher session and successful login
  reprobes/enables the provider; cancel leaves the query intact.
- Captured process environments contain no ambient API keys/endpoints outside the
  explicit allowlist and no credential is persisted by Open Spotlight.
- Cancellation leaves zero provider child processes.
- One opt-in minimal live smoke succeeds for every installed supported provider;
  the phase Grok audit may serve as Grok's single live invocation.

## Verification

Run fixtures, environment capture, process-tree and lifecycle tests plus opt-in
live probes. Record `06-VERIFICATION.md`, then run the bounded Grok audit.

