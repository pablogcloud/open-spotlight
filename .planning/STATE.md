# Project State

**Current phase:** 2 - Durable resumable index
**Status:** Phases 0 and 1 are verified; Phase 2 implementation has not started
**Branch:** `feat/walking-skeleton`
**Repository:** private staging remote at `pablogcloud/open-spotlight`; draft PR #1 targets `main`

## Capability ledger

| Capability | Status | Evidence boundary |
|---|---|---|
| Native launcher shell, hotkey, menu bar, outside-click dismissal | implemented-unverified | Code and prior local harnesses exist; new release gate has not run |
| Spotlight-like visual treatment and provider reveal motion | partial | Multiple iterations exist; no stable frame/real-app acceptance record |
| Claude/Codex/Grok adapters | partial | Adapters and probes exist; version matrix and current live compatibility are unverified |
| Provider selector and authentication UX | partial | Selection UI exists; complete missing/expired-auth flows are unverified |
| App/file/command suggestions | partial | Metadata/index suggestions exist; quality and routing remain incomplete |
| Manual one-file disclosure | partial | Single-file prompt types exist; end-to-end provider disclosure gate must be rerun |
| Local SQLite FTS and embeddings | partial | Prototype indexes limited UTF-8 formats and can return local references |
| Safe approved-root indexing | verified | Phase 1 proves root/scope enforcement, usable-index preservation, honest run state, legacy quarantine and safe local/AI routing |
| Durable pause/resume/crash recovery | absent | Cancellation preserves the usable index, but there is no durable queue, generation or restart checkpoint |
| FSEvents incremental updates | absent | No persistent change-event pipeline |
| PDF/Office extraction | absent | Current support is TXT/Markdown/JSON/CSV only |
| Hybrid filtered retrieval benchmark | absent | No quality corpus or deterministic date/type query gate |
| Retrieved files supplied to the LLM | absent | Indexed suggestions currently open files; they do not create provider context |
| Multi-file disclosure and citations | absent | Provider request supports one manually confirmed file only |
| Extension SDK | absent | Product concept only |
| GitHub open-source readiness | partial | Apache-2.0, notices, community files, private remote, draft PR and live green CI exist; security-email verification, public-only protections/reporting, final audit and publication remain blocked |
| Signed/notarized/updateable distribution | absent | Project signing is disabled |

## Truth rule

Only a phase `NN-VERIFICATION.md` may move a capability to `verified`. That file
must contain the commands and outcomes, real-app evidence where applicable,
known limitations, and the result of the focused Grok audit. Planning prose,
screenshots without interaction evidence, generated projects, or passing unit
tests alone cannot establish completion.

## Immediate next action

Implement Phase 2's versioned migrations, persistent approved roots and
security-scoped bookmarks, durable queue/run generations, pause/resume/cancel,
and crash recovery. In parallel, Phase 9 may resume only after the name,
license, provider-logo, repository ownership and publication gates are approved.
Align the installed CoreSimulator/Xcode versions before the native Xcode gate is
claimed.
