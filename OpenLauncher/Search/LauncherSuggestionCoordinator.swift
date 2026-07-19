import Foundation

actor LauncherSuggestionCoordinator: LauncherSuggestionCoordinating {
    private let metadata: any SpotlightMetadataSearching
    private let localIndex: any LocalIndexServicing
    private let history: LauncherHistoryStore

    init(
        metadata: any SpotlightMetadataSearching = SpotlightMetadataSuggestionSource(),
        localIndex: any LocalIndexServicing,
        history: LauncherHistoryStore = LauncherHistoryStore()
    ) {
        self.metadata = metadata
        self.localIndex = localIndex
        self.history = history
    }

    func suggestions(for request: LauncherSuggestionRequest) async -> [LauncherSuggestion] {
        let query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceLimit = max(request.limit, 6)

        async let metadataValues = metadata.search(query, limit: sourceLimit)
        async let localValues = localSuggestions(query: query, roots: request.indexedRoots, limit: sourceLimit)
        async let historyValues = history.suggestions(
            matching: query,
            provider: request.provider,
            limit: query.isEmpty ? 4 : 2
        )

        var merged = await metadataValues + localValues + historyValues
        merged.append(contentsOf: Self.actionSuggestions(query: query))
        merged.append(contentsOf: Self.promptSuggestions(query: query, provider: request.provider))
        let askSuggestion: LauncherSuggestion? = query.isEmpty ? nil : LauncherSuggestion(
                id: "ask:\(request.provider.rawValue):\(query)",
                kind: .askProvider,
                title: query,
                subtitle: "Ask \(request.provider.displayName)",
                icon: .provider(request.provider),
                action: .ask(query),
                score: 100
            )

        var seenActions = Set<String>()
        let askKey = askSuggestion.map { Self.deduplicationKey($0.action) }
        var ranked = merged
            .sorted {
                if $0.score == $1.score { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                return $0.score > $1.score
            }
            .filter { askKey == nil || Self.deduplicationKey($0.action) != askKey }
            .filter { seenActions.insert(Self.deduplicationKey($0.action)).inserted }
            .prefix(max(0, request.limit - (askSuggestion == nil ? 0 : 1)))
            .map { $0 }
        if let askSuggestion, request.limit > 0 { ranked.append(askSuggestion) }
        return ranked
    }

    func recordSelection(_ suggestion: LauncherSuggestion) async {
        await history.record(suggestion)
    }

    private func localSuggestions(query: String, roots: [URL], limit: Int) async -> [LauncherSuggestion] {
        guard !query.isEmpty, !roots.isEmpty,
              let references = try? await localIndex.search(query, roots: roots, limit: limit)
        else { return [] }

        return references.map { reference in
            LauncherSuggestion(
                id: "index:\(reference.id)",
                kind: .indexedDocument,
                title: reference.title,
                subtitle: Self.compactExcerpt(reference.excerpt),
                icon: .file(reference.fileURL),
                action: .open(reference.fileURL),
                score: 900 + reference.score * 1_000
            )
        }
    }

    private static func actionSuggestions(query: String) -> [LauncherSuggestion] {
        guard !query.isEmpty,
              "settings preferences configuration".localizedCaseInsensitiveContains(query)
        else { return [] }
        return [LauncherSuggestion(
            id: "action:settings",
            kind: .action,
            title: "Open Spotlight Settings",
            subtitle: "Settings",
            icon: .system("gearshape"),
            action: .showSettings,
            score: 780
        )]
    }

    private static func promptSuggestions(query: String, provider: ProviderIdentifier) -> [LauncherSuggestion] {
        guard query.isEmpty else {
            let words = query.split(whereSeparator: \Character.isWhitespace)
            guard words.count <= 3,
                  !query.localizedCaseInsensitiveContains("find "),
                  !query.localizedCaseInsensitiveContains("show ")
            else { return [] }
            let prompt = "Find documents about \(query)"
            return [LauncherSuggestion(
                id: "prompt:\(prompt)",
                kind: .prompt,
                title: prompt,
                subtitle: "Search your files",
                icon: .system("doc.text.magnifyingglass"),
                action: .fillPrompt(prompt),
                score: 240
            )]
        }

        return [
            LauncherSuggestion(
                id: "prompt:find-document",
                kind: .prompt,
                title: "Find a document about…",
                subtitle: "Search your files",
                icon: .system("doc.text.magnifyingglass"),
                action: .fillPrompt("Find a document about "),
                score: 230
            ),
            LauncherSuggestion(
                id: "prompt:explain",
                kind: .prompt,
                title: "Explain an idea…",
                subtitle: "Ask \(provider.displayName)",
                icon: .provider(provider),
                action: .fillPrompt("Explain "),
                score: 220
            ),
        ]
    }

    private static func compactExcerpt(_ excerpt: String) -> String {
        excerpt
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \Character.isWhitespace)
            .prefix(18)
            .joined(separator: " ")
    }

    private static func deduplicationKey(_ action: LauncherSuggestionAction) -> String {
        switch action {
        case let .open(url): "open:\(url.standardizedFileURL.path)"
        case let .ask(query): "ask:\(query.lowercased())"
        case let .fillPrompt(prompt): "fill:\(prompt.lowercased())"
        case .showSettings: "settings"
        }
    }
}
