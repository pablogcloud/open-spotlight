---
phase: 7
mode: mvp
goal: Ship a deterministic, accessible, native-feeling launcher independent of AI
verification: required
---

# Phase 7 Plan - Launcher completeness and native quality

## Deliverables

1. Finish independent app, file/folder, command, calculation, recent/history and
   indexed-document sources with cancellation, stale-result rejection, stable
   fusion/ranking and intentional empty states.
2. Define explicit keyboard routing: Return opens/runs the selected local result;
   Tab or an Ask-AI action promotes the query; provider execution is never a
   fallback for a failed local search.
3. Complete settings for shortcut, screen/position, query reset, answer height,
   provider behavior, approved index roots/exclusions/types, pause/resume/status,
   storage, rebuild/delete, privacy and trust revocation.
4. Verify one menu-bar app instance, configurable shortcut conflicts, cleanup of
   obsolete bundle registrations, outside-click behavior and predictable Escape.
5. Preserve native Spotlight placement on active/multiple displays and preserve
   state across provider/auth/permission handoffs.
6. Use system Liquid Glass APIs where available with macOS 15 semantic-material
   fallback. Lock provider/droplet morphology using frame evidence without a
   visible bounding box, bump, blur, or focus rectangle.
7. Complete VoiceOver labels/order, keyboard focus, contrast, Dynamic Type where
   applicable, Reduce Motion and transparency/accessibility adaptations.
8. Measure launch latency, local result latency, frame pacing and response UI
   under active indexing and provider streaming.

## Acceptance gates

- Routing matrix proves every result/keyboard combination and zero accidental AI
  launches; stale async results never replace a newer query.
- Global shortcut opens one centered launcher on the active display, and outside
  click/Escape/auth handoff behave correctly in the built app.
- Launch p95 is under 150 ms and immediate local-result p95 under 50 ms on the
  recorded reference Mac; motion hits the agreed frame budget under load.
- Provider reveal/open/close frame contact sheets show no visual regression;
  Reduce Motion uses the documented reduced path.
- VoiceOver and keyboard-only UAT pass all launcher/settings/disclosure actions.

## Verification

Run source/routing/performance tests and drive the signed-development app through
the committed lifecycle/motion/accessibility harnesses. Record
`07-VERIFICATION.md`, then run the focused Grok audit.
