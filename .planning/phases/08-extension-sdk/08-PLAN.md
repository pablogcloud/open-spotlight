---
phase: 8
mode: mvp
goal: Prove one constrained community extension shape without an unsafe shell escape
verification: required
---

# Phase 8 Plan - Constrained extension SDK

## Deliverables

1. Define one versioned declarative command manifest and JSON schema. Defer custom
   renderers, generic providers, arbitrary code loading and a marketplace.
2. Declare command identity, input, executable, arguments, file scopes, network
   need, output shape and permissions; reject unknown or overbroad fields.
3. Implement install/validate/enable/disable/remove and compatibility errors.
4. Present permissions before enabling; store grants separately and invalidate
   them when a manifest expands scope.
5. Execute without shell interpolation, with the same environment/output/time/
   cancellation controls used by provider processes.
6. Publish minimal examples and conformance tests without promising unsupported
   extension primitives.

## Acceptance gates

- Invalid, path-escaping, permission-expanding and shell-injection manifests are
  rejected by schema and runtime tests.
- An extension cannot read outside granted scopes, bypass provider disclosure,
  modify index roots, inherit credentials, or leave child processes.
- Revocation disables execution immediately; uninstall removes grants/state.
- Example extensions work from clean checkout and the SDK version mismatch is
  actionable.

## Verification

Run schema/property/security/conformance tests and one real example command.
Record `08-VERIFICATION.md`, then run the bounded Grok audit.

