import Foundation

enum LauncherSuggestionKind: String, Codable, Sendable {
  case application
  case file
  case folder
  case indexedDocument
  case recent
  case action
  case prompt
  case askProvider
}

enum LauncherSuggestionIcon: Equatable, Sendable {
  case file(URL)
  case system(String)
  case provider(ProviderIdentifier)
}

enum LauncherSuggestionAction: Equatable, Sendable {
  case open(URL)
  case ask(String)
  case fillPrompt(String)
  case showSettings

  var invokesProvider: Bool {
    if case .ask = self { true } else { false }
  }
}

struct LauncherSuggestion: Equatable, Identifiable, Sendable {
  let id: String
  let kind: LauncherSuggestionKind
  let title: String
  let subtitle: String?
  let icon: LauncherSuggestionIcon
  let action: LauncherSuggestionAction
  let score: Double

  init(
    id: String,
    kind: LauncherSuggestionKind,
    title: String,
    subtitle: String? = nil,
    icon: LauncherSuggestionIcon,
    action: LauncherSuggestionAction,
    score: Double
  ) {
    self.id = id
    self.kind = kind
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self.action = action
    self.score = score
  }
}

struct LauncherSuggestionRequest: Sendable {
  let query: String
  let provider: ProviderIdentifier
  let indexedRoots: [URL]
  let limit: Int
}

protocol LauncherSuggestionCoordinating: Sendable {
  func suggestions(for request: LauncherSuggestionRequest) async -> [LauncherSuggestion]
  func recordSelection(_ suggestion: LauncherSuggestion) async
}
