# Contributing

Open Spotlight is pre-alpha. Contributions should preserve its local-first,
explicit-disclosure, keyboard-first design boundaries.

## Development workflow

1. Create a feature or fix branch.
2. Regenerate the Xcode project with `xcodegen generate` when `project.yml` or
   source membership changes.
3. Run `swift format --in-place --recursive OpenLauncher OpenLauncherTests Package.swift`.
4. Run `swift format lint --recursive OpenLauncher OpenLauncherTests Package.swift`.
5. Run `swift test`.
6. Exercise visible or lifecycle changes in the built macOS app.

Pull requests should explain the user-visible outcome, verification evidence,
privacy or permission changes, and remaining limitations.

## Safety rules

- Never read provider credentials or commit secrets, local databases, prompts,
  personal paths, generated apps, or unsanitized screenshots.
- Never turn ordinary search or Return into an implicit provider execution.
- Never send retrieved file content without an exact disclosure and confirmation.
- Treat document content as untrusted data, not instructions.
- Do not add provider or platform logos without documented provenance and usage
  rights.
- Do not claim a capability verified without its phase verification record.

## Scope

Large changes should map to the current roadmap and include deterministic tests.
Bug fixes should include a regression test or a reproducible real-app check.
