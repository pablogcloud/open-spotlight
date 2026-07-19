import Foundation

private struct LauncherHistoryEntry: Codable, Sendable {
  enum Kind: String, Codable, Sendable {
    case open
    case ask
  }

  let kind: Kind
  let value: String
  let title: String
  let usedAt: Date
}

actor LauncherHistoryStore {
  private static let key = "launcherSuggestionHistory"
  private let defaults: UserDefaults

  init(suiteName: String? = nil) {
    self.defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
  }

  func record(_ suggestion: LauncherSuggestion) {
    let entry: LauncherHistoryEntry?
    switch suggestion.action {
    case .open(let url):
      entry = LauncherHistoryEntry(
        kind: .open, value: url.path, title: suggestion.title, usedAt: .now)
    case .ask(let query):
      entry = LauncherHistoryEntry(kind: .ask, value: query, title: query, usedAt: .now)
    case .fillPrompt, .showSettings:
      entry = nil
    }
    guard let entry else { return }

    var values = load().filter { !($0.kind == entry.kind && $0.value == entry.value) }
    values.insert(entry, at: 0)
    save(Array(values.prefix(24)))
  }

  func suggestions(matching query: String, provider: ProviderIdentifier, limit: Int)
    -> [LauncherSuggestion]
  {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return load().compactMap { entry -> LauncherSuggestion? in
      guard
        normalized.isEmpty
          || entry.title.lowercased().contains(normalized)
          || entry.value.lowercased().contains(normalized)
      else { return nil }

      switch entry.kind {
      case .open:
        let url = URL(fileURLWithPath: entry.value)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return LauncherSuggestion(
          id: "recent-open:\(url.path)",
          kind: .recent,
          title: entry.title,
          subtitle: "Recent",
          icon: .file(url),
          action: .open(url),
          score: 720 + recencyBoost(entry.usedAt)
        )
      case .ask:
        return LauncherSuggestion(
          id: "recent-ask:\(entry.value)",
          kind: .recent,
          title: entry.title,
          subtitle: "Ask \(provider.displayName) again",
          icon: .provider(provider),
          action: .ask(entry.value),
          score: 660 + recencyBoost(entry.usedAt)
        )
      }
    }
    .sorted { $0.score > $1.score }
    .prefix(limit)
    .map { $0 }
  }

  private func load() -> [LauncherHistoryEntry] {
    guard let data = defaults.data(forKey: Self.key),
      let values = try? JSONDecoder().decode([LauncherHistoryEntry].self, from: data)
    else { return [] }
    return values
  }

  private func save(_ values: [LauncherHistoryEntry]) {
    guard let data = try? JSONEncoder().encode(values) else { return }
    defaults.set(data, forKey: Self.key)
  }

  private func recencyBoost(_ date: Date) -> Double {
    max(0, 80 - Date.now.timeIntervalSince(date) / 3_600)
  }
}
