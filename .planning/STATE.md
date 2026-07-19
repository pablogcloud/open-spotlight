# Project State

**Current phase:** 0 - Evidence re-baseline  
**Status:** Planning complete; implementation not started against the new roadmap  
**Branch:** `feat/walking-skeleton`  
**Repository:** no commits, no configured public remote

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
| Safe approved-root indexing | absent | Whole-volume roots are currently accepted and system paths can dominate the crawl |
| Durable pause/resume/crash recovery | absent | Rebuild deletes the index and has no durable queue/run checkpoint |
| FSEvents incremental updates | absent | No persistent change-event pipeline |
| PDF/Office extraction | absent | Current support is TXT/Markdown/JSON/CSV only |
| Hybrid filtered retrieval benchmark | absent | No quality corpus or deterministic date/type query gate |
| Retrieved files supplied to the LLM | absent | Indexed suggestions currently open files; they do not create provider context |
| Multi-file disclosure and citations | absent | Provider request supports one manually confirmed file only |
| Extension SDK | absent | Product concept only |
| GitHub open-source readiness | absent | No history, remote, license, community files, CI, or asset-rights record |
| Signed/notarized/updateable distribution | absent | Project signing is disabled |

## Truth rule

Only a phase `NN-VERIFICATION.md` may move a capability to `verified`. That file
must contain the commands and outcomes, real-app evidence where applicable,
known limitations, and the result of the bounded Grok audit. Planning prose,
screenshots without interaction evidence, generated projects, or passing unit
tests alone cannot establish completion.

## Immediate next action

Execute Phase 0 re-baseline, then Phase 1. The currently running whole-volume
index is test data, not a production-ready index and must not be represented as
complete.
