# Open Spotlight Design Brief

## Design read

Native macOS search overlay for design-conscious Mac users. Near-system, quiet, translucent, and fluid. Spotlight is the launcher reference; Alcove is a motion-craft reference. The product must preserve keyboard access, reduced motion, legibility, and explicit file disclosure.

## Surface profile: search overlay

- **Mood:** Minimal and restrained
- **Anchor:** macOS Spotlight
- **Calibrated references:** macOS Spotlight, Alcove, Apple Liquid Glass guidance
- **Anti-pattern flags acknowledged:** no dashboard chrome, helper footer, provider rail, stacked glass cards, AI gradients, or decorative status text
- **Last calibrated:** 2026-07-18

## Launcher

At rest, the launcher is one centered search capsule. It contains a standard magnifying glass and a large system search field. It contains no title, subtitle, provider rail, suggestion cards, privacy badge, keyboard legend, or persistent status copy.

The provider control is a single circular trailing control. It appears when the pointer enters the launcher, when the selected provider needs attention, or while a response is running. During generation it becomes the Stop control. Provider names and connection details live inside its menu, not on the launcher face.

Results and answers expand beneath the search capsule only when content exists. This content surface uses a standard macOS material. Liquid Glass is reserved for the interactive search and provider controls.

## Liquid Glass

On macOS 26 and later, use SwiftUI `glassEffect`, `GlassEffectContainer`, interactive glass, and matched glass identities. Let the system adapt lensing, vibrancy, contrast, and accessibility. On macOS 15, fall back to semantic regular materials and a restrained inner keyline.

Never approximate Liquid Glass with a milky opaque fill. Glass is a functional layer with adaptive lensing and interactive response.

## Motion

- Opening: 320 ms damped spring, opacity and 0.975 scale from the top edge.
- Provider reveal: 300 ms spring. The capsule yields space to the circular provider control.
- Expansion: preserve the top edge while the window grows downward over 300 ms.
- Results: stable text layout with no per-token animation.
- Dismissal: immediate on Escape or outside click. A running provider is cancelled.
- Reduce Motion: opacity only, no scale or translation, maximum 80 ms.

## Onboarding and settings

Onboarding is a separate native window with three moments: product introduction, provider connection, and shortcut selection. It is not embedded in the launcher. At least one provider must be connected before finishing.

Provider authentication launches each installed CLI's official interactive login process in Terminal. Open Spotlight does not read, copy, synchronize, or store provider credentials. Missing CLIs route to official installation guidance.

The menu-bar item remains available at all times. It opens Open Spotlight, provider settings, shortcut settings, and Quit.

Settings use a standard grouped macOS form rather than a custom dashboard. The implemented controls cover the default provider, global shortcut, screen position, answer height, query reset behavior, provider-control reveal, outside-click dismissal, glass contrast, and app-specific reduced motion. Provider rows use the providers' recognizable miniature marks and show connection state or the next setup action.

The Local Index section must label the current implementation as an **early text-only partial index**. It must show selected roots, current run state, retained-document counts, progress/errors, cancellation, rebuild, and deletion, and state plainly that durable resume, incremental events, PDF/Office extraction, and production retrieval are not built.
