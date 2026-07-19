import Foundation
import XCTest

@testable import OpenLauncher

final class LauncherSuggestionTests: XCTestCase {
  func testCoordinatorRanksNativeAndIndexedResultsAheadOfPromptAndAsk() async {
    let nativeURL = URL(fileURLWithPath: "/Applications/Numbers.app")
    let indexedURL = URL(fileURLWithPath: "/tmp/Approved/budget.md")
    let metadata = StubMetadataSearch(values: [
      LauncherSuggestion(
        id: "metadata:numbers",
        kind: .application,
        title: "Numbers",
        subtitle: "Application",
        icon: .file(nativeURL),
        action: .open(nativeURL),
        score: 1_000
      )
    ])
    let localIndex = StubLocalIndex(references: [
      LocalSearchReference(
        id: "budget:0",
        fileURL: indexedURL,
        title: "Budget",
        excerpt: "Construction budget for Merida",
        modifiedAt: .now,
        score: 0.9,
        lexicalRank: 1,
        semanticRank: 1
      )
    ])
    let suite = "OpenSpotlightSuggestionTests.\(UUID().uuidString)"
    let coordinator = LauncherSuggestionCoordinator(
      metadata: metadata,
      localIndex: localIndex,
      history: LauncherHistoryStore(suiteName: suite)
    )

    let values = await coordinator.suggestions(
      for: LauncherSuggestionRequest(
        query: "budget",
        provider: .codex,
        indexedRoots: [URL(fileURLWithPath: "/tmp/Approved")],
        limit: 6
      ))

    XCTAssertEqual(values.first?.title, "Budget")
    XCTAssertTrue(values.contains { $0.kind == .application })
    XCTAssertEqual(values.last?.kind, .askProvider)
    XCTAssertEqual(values.last?.action, .ask("budget"))
  }

  func testEmptyQueryOffersQuietPromptStartersWithoutAnAskFallback() async {
    let suite = "OpenSpotlightSuggestionTests.\(UUID().uuidString)"
    let coordinator = LauncherSuggestionCoordinator(
      metadata: StubMetadataSearch(values: []),
      localIndex: StubLocalIndex(references: []),
      history: LauncherHistoryStore(suiteName: suite)
    )

    let values = await coordinator.suggestions(
      for: LauncherSuggestionRequest(
        query: "",
        provider: .claude,
        indexedRoots: [],
        limit: 6
      ))

    XCTAssertEqual(values.map(\.title), ["Find a document about…", "Explain an idea…"])
    XCTAssertFalse(values.contains { $0.kind == .askProvider })
  }

  func testHistoryDeduplicatesRepeatedSelections() async {
    let suite = "OpenSpotlightSuggestionHistory.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = LauncherHistoryStore(suiteName: suite)
    let suggestion = LauncherSuggestion(
      id: "ask-one",
      kind: .askProvider,
      title: "project status",
      icon: .provider(.codex),
      action: .ask("project status"),
      score: 0
    )

    await store.record(suggestion)
    await store.record(suggestion)
    let values = await store.suggestions(matching: "", provider: .codex, limit: 5)

    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.first?.action, .ask("project status"))
  }

  func testAskProviderAlwaysKeepsTheLastVisibleSlot() async {
    let metadataValues = (0..<8).map { index in
      let url = URL(fileURLWithPath: "/tmp/budget-\(index).md")
      return LauncherSuggestion(
        id: "metadata:\(index)",
        kind: .file,
        title: "Budget \(index)",
        icon: .file(url),
        action: .open(url),
        score: Double(1_000 - index)
      )
    }
    let suite = "OpenSpotlightSuggestionTests.\(UUID().uuidString)"
    let coordinator = LauncherSuggestionCoordinator(
      metadata: StubMetadataSearch(values: metadataValues),
      localIndex: StubLocalIndex(references: []),
      history: LauncherHistoryStore(suiteName: suite)
    )

    let values = await coordinator.suggestions(
      for: LauncherSuggestionRequest(
        query: "budget",
        provider: .grok,
        indexedRoots: [],
        limit: 6
      ))

    XCTAssertEqual(values.count, 6)
    XCTAssertEqual(values.last?.kind, .askProvider)
    XCTAssertEqual(values.last?.subtitle, "Ask Grok")
  }
}

private actor StubMetadataSearch: SpotlightMetadataSearching {
  let values: [LauncherSuggestion]

  init(values: [LauncherSuggestion]) {
    self.values = values
  }

  func search(_ query: String, limit: Int) -> [LauncherSuggestion] {
    Array(values.prefix(limit))
  }
}

private actor StubLocalIndex: LocalIndexServicing {
  let references: [LocalSearchReference]

  init(references: [LocalSearchReference]) {
    self.references = references
  }

  func search(_ query: String, roots: [URL], limit: Int) -> [LocalSearchReference] {
    Array(references.prefix(limit))
  }

  func rebuild(roots: [URL]) -> LocalIndexStatistics {
    LocalIndexStatistics(documents: references.count, chunks: references.count)
  }

  func statistics(roots: [URL]) -> LocalIndexStatistics {
    LocalIndexStatistics(documents: references.count, chunks: references.count)
  }

  func clear(roots: [URL]) {}
}
