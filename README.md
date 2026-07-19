# Open Spotlight

Open Spotlight is an experimental native macOS launcher that combines normal
app and file search with locally installed Claude Code, Codex CLI, and Grok
Build CLI providers.

> **Pre-alpha:** this repository is under active development. There is no
> supported or notarized public binary. Provider marks identify compatible
> user-installed tools; they do not imply affiliation or endorsement.

Open Spotlight is an independent project. It is not affiliated with, sponsored
by, or endorsed by Apple, Anthropic, OpenAI, or xAI.

## Current capability

The development build currently provides:

- a native menu-bar launcher with a configurable global shortcut;
- Spotlight metadata, local-index, history, action, and explicit AI suggestions;
- independent adapters for Claude Code, Codex CLI, and Grok Build CLI;
- streaming, cancellation, provider probing, and provider-specific login launch;
- manual attachment and disclosure for one UTF-8 text file;
- an early approved-folder SQLite FTS and on-device sentence-embedding index.

It does **not** yet provide durable resumable indexing, FSEvents updates, PDF or
Office extraction, production retrieval benchmarks, indexed multi-file context,
cited file-aware answers, an extension SDK, or a signed public release. The
current capability ledger is [.planning/STATE.md](.planning/STATE.md).

## Development requirements

- macOS 15 or later
- Xcode 26 or later with Swift 6 support
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- one or more supported provider CLIs for live provider testing

The most recently recorded local baseline uses XcodeGen 2.44.1, Swift 6.3.3,
Claude Code 2.1.214, Codex CLI 0.144.1, and Grok 0.2.103. Provider compatibility
is version-sensitive and is not guaranteed beyond verified fixtures.

The app includes macOS 26 Liquid Glass code behind runtime availability checks,
so compilation still requires an SDK that defines those symbols. Older macOS
versions use the material fallback at runtime.

## Build and test

```sh
xcodegen generate
swift test
open OpenLauncher.xcodeproj
```

The Swift package is the current reproducible verification path. GitHub Actions
checks strict formatting, runs the complete Swift test suite, regenerates the
Xcode project, and exercises unsigned native Debug and Release builds. Signing
remains disabled for development builds.

## Provider model

Open Spotlight locates CLIs installed by the user and asks each CLI to use its
own existing authentication. The app does not copy or store provider tokens.
Users remain responsible for installing each CLI, maintaining an eligible
provider account, and complying with the provider's terms.

Every adapter uses an isolated working directory and the strongest verified
noninteractive restrictions available to that CLI. These controls reduce ambient
access but are not presented as an operating-system security boundary.

## Local and remote data flow

- Spotlight metadata search and the approved-folder index run locally.
- Indexed chunks and on-device embeddings are stored in the app's Application
  Support directory.
- Indexed search results currently open local files; they are not silently added
  to provider prompts.
- A provider starts only after an explicit AI action.
- A manually attached file is sent only after the disclosure is confirmed.
- The selected provider CLI, not Open Spotlight, controls remote processing and
  account retention.

See [PRIVACY.md](PRIVACY.md) for the current technical boundary.

## Project status

The evidence-gated implementation plan lives in [.planning/ROADMAP.md](.planning/ROADMAP.md).
Phase 0 and Phase 1 are verified. Phase 2, durable resumable indexing, is the
current implementation phase. This repository is a source-only pre-alpha; its
publication evidence and remaining release limitations are tracked separately
in Phase 9.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change. Please do not
report suspected vulnerabilities in a public issue; follow [SECURITY.md](SECURITY.md).

## License

Open Spotlight is licensed under the [Apache License 2.0](LICENSE). Provider
names and logos remain the property of their respective owners and are not
licensed under Apache-2.0; see [NOTICE.md](NOTICE.md).
