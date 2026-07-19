# Walking-skeleton requirements

These are acceptance targets, not current capability claims. Current status and
evidence live in `STATE.md` and the numbered phase verification records.

## Launcher

- **LAUNCH-01:** A configurable global shortcut opens and closes a native launcher panel.
- **LAUNCH-02:** Opening focuses the prompt field; Escape cancels a request first and closes the panel when idle.
- **LAUNCH-03:** The panel opens within 150 ms under normal local load.
- **LAUNCH-04:** App, file, and built-in command placeholders render without waiting for a provider.

## Providers

- **PROV-01:** Claude Code, Codex CLI, and Grok Build CLI conform to one adapter interface.
- **PROV-02:** Each adapter reports executable presence and version without reading credentials.
- **PROV-03:** Each adapter streams normalized text events and a terminal completion or error event.
- **PROV-04:** Requests can be cancelled without leaving child processes running.
- **PROV-05:** Failure or missing authentication in one adapter does not affect the others.
- **PROV-06:** Effective provider permissions and ambient-context limitations are documented in the UI.

## Context disclosure

- **CTX-01:** The user can attach one local text file through a standard open panel.
- **CTX-02:** Before submission, the launcher displays the complete launcher-supplied payload summary: file name, size, extracted character count, and provider.
- **CTX-03:** File contents are never sent until the user confirms the request.
- **CTX-04:** The provider prompt marks attached content as untrusted data and requests a source citation.

## Interaction and accessibility

- **UX-01:** Claude, Codex, and Grok are switchable from the keyboard.
- **UX-02:** Idle, probing, streaming, completed, cancelled, empty, and error states are visually distinct.
- **UX-03:** Streaming always exposes a visible Stop action.
- **UX-04:** Entrance, provider switching, response reveal, and cancellation have interruptible feedback.
- **UX-05:** Reduce Motion replaces spatial transitions with short opacity changes or no animation.
- **UX-06:** Keyboard focus remains visible and VoiceOver labels identify controls and provider status.

## Verification

- **VERIFY-01:** Unit tests cover parser behavior, state transitions, prompt construction, provider isolation, and cancellation semantics using fake executables.
- **VERIFY-02:** Xcode build and test commands pass on the installed toolchain.
- **VERIFY-03:** Opt-in live smoke probes confirm each installed CLI emits usable output without exposing secrets.
- **VERIFY-04:** The running application is visually inspected in idle, streaming, completed, and error states.
