# Open Spotlight - Product Brief

**Status:** Draft 0.2  
**Date:** 2026-07-17  
**Product name:** Open Spotlight

## Executive summary

Open Spotlight is a free, open-source macOS launcher with the speed and refinement people expect from Spotlight, but without requiring a second AI subscription. It discovers supported AI command-line tools already installed and authenticated on the Mac, launching with Claude Code, Codex, and Grok Build, and lets people use them from a fluid keyboard-first interface.

The launcher is local-first. Apps, files, commands, settings, and indexed content remain on the device. When an AI request needs local context, Open Spotlight retrieves only the relevant material, discloses what will be shared, and passes it to the selected CLI using the strongest noninteractive safety controls that CLI supports.

The project is not an invoice tool, file chatbot, or literal clone of Raycast. It is an open launcher runtime: a polished native shell, a provider-adapter layer, a local context engine, and an extension platform that the community can adapt to new models and workflows.

## The problem

macOS users currently make several compromises:

- Spotlight is fast and built in, but it does not provide an extensible conversational or agent interface.
- Commercial launchers are polished, but their AI features can require an additional subscription or API key.
- AI CLIs already have access to capable models through subscriptions users pay for, but they live in terminals and are not designed for quick system-wide use.
- Local file search is usually lexical or filename-based. Semantic tools frequently require uploading large amounts of personal data or trusting a proprietary index.
- Extensible launchers depend on one company to approve features, providers, pricing, and integrations.

## Product thesis

If a launcher combines native macOS quality, existing CLI authentication, private local context, and an open extension model, it can become the fastest way to launch, find, and ask on a Mac without introducing another AI bill or another closed data silo.

The promise should be precise:

> Use the AI tools and subscriptions you already have, where their official CLIs support authenticated noninteractive use.

Open Spotlight does not promise that every subscription or CLI will work forever. Provider adapters are compatibility layers over tools and terms controlled by their vendors.

Official noninteractive use, subscription eligibility, automation permissions, and output stability must be verified separately for every provider version. Adapter viability is a release gate, not an assumption.

## Target users

### Primary

- Developers and technical professionals already using Claude Code, Codex, Grok Build, Ollama, or similar tools.
- Keyboard-first Mac users who want a free and open alternative to closed launchers.
- Privacy-conscious users who want local indexing and explicit control over model context.

### Secondary

- Open-source contributors building commands, themes, context providers, and model adapters.
- Small teams that want standardized launcher workflows without routing their data through a new model reseller.
- Organizations that need auditable, managed access to approved AI CLIs and internal context sources.

## Core jobs to be done

1. Open apps, files, settings, commands, and recent items without leaving the keyboard.
2. Turn the current query into a question for an already authenticated AI CLI.
3. Find information by meaning rather than exact filenames.
4. Ask questions that combine natural language, local context, and deterministic filters such as dates or file types.
5. Add new commands and data sources without waiting for the core maintainers.
6. Understand what local information is being sent to a remote model before it leaves the Mac.

## Product principles

### Instant before intelligent

The launcher must remain useful and fast when every AI provider is offline. Local results appear immediately; AI enrichment streams afterward.

### Local-first, not privacy theater

Indexing, embeddings, ranking, history, and permissions are local by default. The application clearly distinguishes local processing from content sent through a provider CLI.

### Existing authentication, never copied credentials

Open Spotlight invokes supported CLIs as the current user. It does not extract, proxy, synchronize, or store provider tokens.

### Open core means genuinely useful core

The free build includes the launcher, local search, provider adapters, context engine, extension SDK, security updates, and normal release channel. Monetization must not intentionally degrade these capabilities.

### Motion serves comprehension

Animation should preserve spatial continuity, communicate state, and make streaming feel alive. It must be interruptible, maintain high frame rates, and respect Reduce Motion.

### Answers expose evidence

File-aware responses cite the local source, location, and relevant excerpt. The interface makes it easy to open, reveal, or preview the evidence.

## Core experience

1. The user presses a global hotkey.
2. A native panel appears with the text field already focused.
3. Local results—applications, files, commands, calculations, and extensions—update as the user types.
4. The user presses `Tab` or selects an AI action to promote the query into an AI request.
5. Open Spotlight selects the configured provider or lets the user switch providers.
6. If local context would help, the retrieval engine proposes relevant sources and scopes.
7. Folder indexing is approved once. Sending retrieved content to a remote provider requires disclosure and confirmation until the user explicitly marks that source-provider pairing as trusted.
8. The selected CLI receives the disclosed launcher-supplied payload through a restricted noninteractive invocation. Any provider-added instructions, hooks, memory, or ambient configuration must be disabled, detected, or separately disclosed by its adapter.
9. The response streams into the panel with citations and follow-up actions.
10. `Escape` always cancels or closes predictably.

## Platform architecture

### Native shell

- Swift and AppKit for the application lifecycle, global panel, focus behavior, keyboard event handling, Quick Look, and macOS integration.
- SwiftUI where it improves composability without compromising input latency or animation control.
- Direct signed and notarized distribution. Mac App Store distribution is not an initial goal because sandboxing conflicts with launching arbitrary user-installed executables.

### Search engine

- Immediate fuzzy search over applications, commands, settings, and indexed filenames.
- Local full-text index for supported documents.
- Optional multilingual embeddings for semantic retrieval.
- Metadata filters for path, type, created date, modified date, extracted dates, and source.
- Incremental updates using macOS file-system events.

#### Local index design boundary

The current development build contains an **early, text-only partial index** for folders the user explicitly selects. It stores SQLite FTS rows and prototype on-device embeddings for TXT, Markdown, JSON, and CSV files. It now rejects whole-volume and operating-system roots, excludes hidden/package/credential/dependency paths, preserves the previous usable index during a rebuild, and quarantines legacy unsafe generations. It is not resumable, incremental, benchmarked, or ready for a public release. The production index remains gated on these stages:

1. **Scope:** index only folders the user selects. Hidden files, package contents, credential directories, and explicit exclusions are denied before extraction.
2. **Observe:** seed a bounded crawl, then use file-system events to enqueue additions, edits, renames, and removals. The queue must coalesce duplicate events and survive restarts.
3. **Extract:** normalize metadata and text through type-specific extractors. Initial support targets plain text, Markdown, PDF, and common office documents; unsupported or protected files remain metadata-only.
4. **Store:** keep metadata, excerpts, and an FTS5 lexical index in a local SQLite database. Optional local embeddings live in a separate versioned table so semantic indexing can be disabled or rebuilt independently.
5. **Retrieve:** parse deterministic filters such as date, type, and source first; retrieve lexical and semantic candidates; fuse and rerank them; return cited excerpts and local file URLs.
6. **Disclose:** retrieval stays local. Before any excerpt is placed in a provider prompt, show the exact files, extracted character counts, and destination provider, then require confirmation.

Current Settings exposes selected roots, run status, progress/error counters, cancellation, rebuild, and deletion with explicit partial-state copy. Later phases must add excluded-path/file-type controls, durable pause/resume, storage accounting, crash recovery, and the remaining production gates. No public background indexer should ship until scoped-access tests prove that excluded and unapproved content cannot enter the database or a provider payload.

### Provider adapters

Each adapter implements a stable internal contract:

- `probe`: locate the executable, version, authentication readiness, and capabilities.
- `invoke`: submit prompt and context without shell interpolation.
- `stream`: normalize provider-specific streaming output.
- `cancel`: terminate the request and its child processes.
- `health`: report quota, authentication, incompatibility, and configuration errors.

First-party adapters:

- Claude Code
- Codex CLI
- Grok Build CLI

The first release treats these three adapters as a single launch requirement, not a sequence of provider experiments. Local-model adapters such as Ollama follow after the shared provider contract is stable.

Community adapters may use a declarative manifest when a CLI exposes a safe noninteractive interface. Interactive-only tools require purpose-built integrations and are not guaranteed.

Provider safety flags and an isolated working directory reduce accidental access, but they are not an operating-system security boundary. Until stronger containment is implemented and verified, the product must describe execution as constrained or best-effort—not sandboxed—and expose each adapter's effective permissions.

### Extension system

The extension SDK should distinguish five primitives:

- **Command:** a user-triggered operation.
- **Search source:** returns ranked launcher results.
- **Context source:** supplies explicitly scoped information to an AI request.
- **Provider:** invokes and normalizes an AI CLI or local model.
- **Renderer:** displays a standard or custom result view.

Extensions declare permissions, executable access, network access, file scopes, and data they may send to a provider. The application displays and enforces these declarations. This is the long-term platform model; the first prototype does not implement all five primitives.

## Walking-skeleton prototype

The first implementation proves one complete loop across the three launch providers before the project commits to a platform:

- Global hotkey opens a polished launcher.
- Applications, files, and built-in commands appear instantly.
- Claude Code, Codex, and Grok Build are detected independently.
- Each provider is invoked, streamed, cancelled, and normalized through the same internal contract.
- Authentication or compatibility failure in one provider does not prevent the other two from working.
- The user can attach one local file manually.
- The complete launcher-supplied prompt and attachment payload is visible before submission.
- The streamed answer cites the attached file.
- Motion, launch latency, focus behavior, and cancellation are measured on real hardware.

The prototype includes only an unverified local-index experiment; it does not include durable semantic indexing, an extension marketplace, cloud sync, or enterprise controls.

## Public MVP

The first public release hardens the three-provider skeleton and adds systems that must each pass their own feasibility gate:

- Claude Code, Codex, and Grok Build adapters with current-version fixtures and explicit capability reporting.
- User-approved folder indexing, hybrid retrieval, context disclosure, and cited file-aware answers.
- One constrained declarative extension shape for community commands.
- Signed, notarized builds and a free signed update channel.
- Consent-based crash and compatibility diagnostics that never include prompts or indexed contents.

Public-release gates include provider-version fixtures; verified tool-disabled or query-only operation where available; disclosure of any residual provider capability or ambient configuration; scoped-index access tests; retrieval quality benchmarks; extension permission tests; notarization; update-signature verification; and diagnostics redaction tests.

## Explicit non-goals for the MVP

- Reproducing every Raycast utility or extension.
- Supporting every CLI through a generic shell command field.
- Autonomous file modification or unrestricted shell execution.
- Calendar, email, browser, window-management, and team collaboration suites.
- Cross-device synchronization.
- A proprietary model gateway or resale of model tokens.
- Mac App Store distribution.

## Differentiation

Open Spotlight should not compete on having the longest feature checklist. Its durable differentiation is the combination of:

- No required launcher AI subscription.
- Reuse of supported, already authenticated CLIs.
- Local-first semantic context with explicit disclosure.
- Native macOS speed and interaction quality.
- Provider independence.
- An open, community-extensible ecosystem.
- Transparent provider permissions and documented execution boundaries.

## Open-source strategy

### Recommended structure

- Keep the complete local desktop experience open source.
- Keep the provider adapter contract and extension SDK permissive enough for broad adoption.
- Retain the project name and visual identity as trademarks so unofficial forks cannot impersonate official releases.
- Make governance, release signing, security policy, and compatibility guarantees explicit.
- Publish reproducible build instructions and a transparent security model.
- Define community control concretely through public proposals, contribution rules, maintainer roles, and transparent registry moderation; do not use “community-owned” as a substitute for governance.

### Provisional licensing direction

Use a weak-copyleft license such as MPL-2.0 for the core application and a permissive license such as Apache-2.0 for the extension SDK and examples. This encourages commercial extensions while requiring modifications to core licensed files to remain open. Final license selection requires dedicated legal review before accepting outside contributions. Do not rely on dual licensing as revenue unless the project establishes the necessary contributor-copyright or contributor-agreement structure upfront.

## Business model

### Recommendation

Do not depend solely on donations if the ambition is to employ maintainers, fund design work, sign and notarize builds, operate compatibility testing, and support users reliably.

Donations and sponsorships are appropriate during the community-building stage and should remain available permanently. They are not predictable enough to be the only long-term revenue source. Home Assistant reached a similar conclusion: its founders kept the core open and free while creating a paid convenience service whose recurring revenue funds ongoing open-source development.

The recommended business hypothesis is:

> Free local core + optional paid convenience services + paid organizational capabilities + sponsorships.

### Always free

- Native launcher and local search.
- CLI provider adapters.
- Local context index.
- Extension runtime and public registry access.
- Normal signed releases and security updates.
- Themes, import/export, and local configuration.
- Self-built and community-built binaries.

### Funding layer 1: community support

Start with GitHub Sponsors and, once contributors or shared expenses justify it, an Open Collective.

Possible supporter benefits that do not weaken the core product:

- Public supporter badge or credits entry.
- Development updates and roadmap calls.
- Nightly or preview release channel.
- Voting signals on non-security roadmap priorities.
- Sponsor-only community sessions.

These are recognition and participation benefits, not essential product functions.

### Funding hypothesis 2: optional personal cloud convenience

A future paid service could provide:

- End-to-end encrypted synchronization of settings, commands, themes, and extension configuration.
- Encrypted backup and restoration.
- Device handoff and shared personal workflows.
- Hosted compatibility diagnostics that do not receive indexed document contents.

The local product remains fully usable without an account or this service. A preliminary target could be USD 4–6 per month or USD 40–60 per year, validated through willingness-to-pay research rather than assumed.

### Funding hypothesis 3: teams and enterprise

Organizations may become the strongest for-profit opportunity because they pay for control, assurance, and support—not for the open launcher itself. This is a separate buyer and product surface, so it must be validated through interviews and pilots before enterprise infrastructure is built.

Potential paid capabilities:

- Managed provider and model policies.
- Signed private extension registries.
- Team-distributed commands and context connectors.
- SSO, SCIM, role-based access, and MDM deployment packages.
- Audit events that record actions without capturing prompt or document contents by default.
- Approved-folder and data-egress policies.
- Long-term support releases, security response commitments, and support SLAs.
- Commercial assistance for custom internal integrations.

### Funding hypothesis 4: ecosystem and services

- Optional paid extensions or workflow packs with a marketplace revenue share.
- Commercial support and integration contracts.
- Commercial/OEM support or alternative licensing only if future governance and contributor rights make it legally possible.
- Hardware or provider sponsorships only when clearly labeled and unable to influence default routing or search ranking.

### Business-model guardrails

- Do not sell model tokens or add a margin to users' existing AI subscriptions.
- Do not sell browsing, query, file, or prompt data.
- Do not place advertisements in launcher results.
- Do not make security updates, standard provider adapters, or local indexing paid.
- Do not privilege sponsored providers in automatic routing.
- Do not require an account for the local application.
- Publish a plain-language explanation of how commercial revenue funds the open project.

## Why not donation-only?

Donation-only is viable if Open Spotlight remains a small maintainer-led project with modest operating costs. It becomes fragile if the project needs full-time engineering, provider compatibility work, design, support, security response, release infrastructure, or a team.

GitHub Sponsors and Open Collective make one-time and recurring support straightforward and transparent, but voluntary support should be treated as variable funding. It can finance early development, contributors, audits, and community work while product-market fit is still uncertain.

The decision does not need to be made permanently at launch. The project can begin donation-supported while deliberately preserving clean seams for optional hosted and organizational services later.

## Commercial validation gates

Treat every paid layer as a hypothesis until evidence exists:

1. Interview at least 20 retained target users about switching behavior, trust, and willingness to pay.
2. Measure whether the free product retains users before building paid infrastructure.
3. Test encrypted-sync demand with a landing page or concierge prototype before operating a sync service.
4. Interview at least 10 organizations and secure three credible design partners before building SSO, SCIM, MDM, audit, or private-registry features.
5. Validate marketplace demand from both extension authors and buyers before implementing payments.
6. Keep sponsorship revenue separate from product-revenue forecasts.

## Success measures

### Product quality

- Launcher appears within 150 milliseconds of the hotkey under normal load.
- Local keystroke-to-result latency remains below 50 milliseconds at the 95th percentile.
- Supported provider adapters successfully detect readiness without reading credentials.
- Cancellation leaves no orphaned provider process.
- No indexed content outside user-approved scopes appears in retrieval traces.
- File-aware answers include usable evidence links.
- Core interactions maintain 60 frames per second and target 120 on supported displays.

### Adoption

- With explicit opt-in diagnostics: weekly active users, four-week retention, first-provider-request completion, context-source activation, and provider compatibility failures.
- Without diagnostics: signed-update checks, download counts, voluntary surveys, and privacy-preserving in-app export of local usage statistics chosen by the user.
- Number of maintained community extensions and provider adapters, observable through the public registry.

No telemetry mode may collect prompts, retrieved excerpts, filenames, local paths, or indexed content.

### Sustainability

- Individual sponsor conversion and monthly recurring sponsorship.
- Number of organizations requesting managed deployment or support.
- Paid-service conversion only after the free product demonstrates retention.
- Maintainer hours and infrastructure costs covered by recurring revenue.

## Major risks

### Provider restrictions and instability

CLI flags, output formats, authentication methods, quotas, and terms can change. Mitigation: versioned adapters, compatibility fixtures, capability probing, and honest support matrices.

### Becoming a shallow clone

Attempting feature parity with Raycast would dilute the unique proposition. Mitigation: protect the walking-skeleton loop and extension platform before expanding horizontally.

### Performance degradation

Semantic indexing and animated UI can make a launcher feel heavy. Mitigation: local results never wait for AI, background indexing is throttled, and motion has measurable frame-time budgets.

### Prompt injection through local content

Indexed files may contain instructions intended to manipulate a model. Mitigation: treat retrieved text as untrusted data, disable or constrain provider tools where supported, disclose outgoing context, document residual access, and avoid claiming an operating-system sandbox until one is verified.

### Open-source trust erosion

Aggressive feature gating could undermine the project's reason to exist. Mitigation: publish the always-free commitment and commercial guardrails before monetization begins.

## Phased roadmap

The execution roadmap is maintained in `.planning/ROADMAP.md`. Capability claims move to `verified` only through the phase verification records defined there; this brief describes the intended product, not the current completion state.

## Decisions still required

1. Final product name and brand territory.
2. Minimum supported macOS version and Intel support policy.
3. Exact boundary between AppKit and SwiftUI.
4. Extension isolation mechanism and implementation language options.
5. Local embedding model, distribution size, language coverage, and license.
6. Exact opt-in diagnostics design and which success metrics remain possible without it.
7. Final open-source licenses, governance, contributor-rights, and commercial-boundary policy.
8. Default-provider behavior: explicit user choice, remembered preference, or transparent automatic routing.
9. Whether the project begins as a community project, a company-backed project, or a project with a later commercial entity.

## Recommended immediate next step

Build a two-week feasibility prototype that demonstrates the complete interaction without a production index:

1. Native global launcher panel.
2. App and file result list.
3. Streaming Claude Code, Codex, and Grok Build adapters running from dedicated working directories with documented effective permissions.
4. A shared adapter conformance harness covering detection, invocation, streaming, cancellation, malformed output, missing authentication, and provider-specific failure.
5. One manually attached local file with complete launcher-supplied payload disclosure and a cited answer from each provider.
6. Reliable cancellation with no orphaned process for all three providers.
7. Motion prototype with measured launch and frame-time performance.

Do not begin the complete extension marketplace, cloud sync, or broad file extraction system until this loop feels fast and desirable.

## Reference examples

- [Home Assistant's original open-core sustainability rationale](https://www.home-assistant.io/blog/2018/09/17/thinking-big/)
- [Nabu Casa pricing and paid convenience service](https://www.nabucasa.com/pricing/)
- [Bitwarden's open-source, hosted, and enterprise model](https://bitwarden.com/pricing/business/)
- [GitHub Sponsors fees and recurring sponsorships](https://docs.github.com/en/sponsors/sponsoring-open-source-contributors/about-sponsorships-fees-and-taxes)
- [Open Collective's transparent funding model](https://opencollective.com/how-it-works)
- [Apple guidance on macOS sandbox file and executable access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [xAI Grok Build headless and streaming interface](https://docs.x.ai/build/cli/headless-scripting)
- [xAI subscription OAuth support for external open-source integrations](https://x.ai/news/grok-opencode)
