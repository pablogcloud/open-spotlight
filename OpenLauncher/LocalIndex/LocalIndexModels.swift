import Foundation

struct LocalIndexDocument: Equatable, Sendable {
  let url: URL
  let title: String
  let text: String
  let modifiedAt: Date

  init(url: URL, title: String? = nil, text: String, modifiedAt: Date = .now) {
    self.url = url.standardizedFileURL
    self.title = title ?? url.deletingPathExtension().lastPathComponent
    self.text = text
    self.modifiedAt = modifiedAt
  }
}

struct LocalIndexChunk: Equatable, Sendable {
  let ordinal: Int
  let text: String
  let startOffset: Int
  let endOffset: Int
}

struct LocalEmbedding: Equatable, Sendable {
  let model: String
  let values: [Float]
}

struct LocalSearchReference: Equatable, Identifiable, Sendable {
  let id: String
  let fileURL: URL
  let title: String
  let excerpt: String
  let modifiedAt: Date
  let score: Double
  let lexicalRank: Int?
  let semanticRank: Int?

  var citationLabel: String { "\(title) · excerpt \(id.suffix(4))" }
}

enum LocalIndexError: Error, Equatable, LocalizedError, Sendable {
  case unapprovedURL(URL)
  case forbiddenRoot(URL, String)
  case unsupportedFileType(String)
  case invalidDatabase(String)
  case embeddingUnavailable

  var errorDescription: String? {
    switch self {
    case .unapprovedURL(let url): "The file is outside the approved index folders: \(url.path)"
    case .forbiddenRoot(let url, let reason): "The folder cannot be indexed: \(url.path). \(reason)"
    case .unsupportedFileType(let extensionName):
      "The file type .\(extensionName) is not supported by the local index."
    case .invalidDatabase(let message): "The local index database failed: \(message)"
    case .embeddingUnavailable: "An on-device sentence embedding is unavailable for this text."
    }
  }
}

protocol LocalEmbeddingProviding: Sendable {
  func embedding(for text: String) -> LocalEmbedding?
}

struct LocalIndexScope: Equatable, Sendable {
  static let supportedExtensions: Set<String> = ["txt", "md", "markdown", "json", "csv"]
  static let deniedComponents: Set<String> = [
    ".git", ".ssh", ".gnupg", ".aws", ".azure", ".claude", ".codex", ".grok",
    ".kube", ".npm", ".swiftpm", ".build", "keychains", "node_modules", "pods",
    "carthage", "deriveddata", "vendor",
  ]
  static let deniedPackageExtensions: Set<String> = [
    "app", "bundle", "framework", "plugin", "appex", "xcodeproj", "xcworkspace", "playground",
  ]

  let approvedRoots: [URL]
  let excludedURLs: [URL]

  init(approvedRoots: [URL], excludedURLs: [URL] = []) {
    self.approvedRoots = LocalIndexRootPolicy.allowedRoots(from: approvedRoots)
    self.excludedURLs = excludedURLs.map { $0.resolvingSymlinksInPath().standardizedFileURL }
  }

  func allows(_ candidate: URL) -> Bool {
    let url = candidate.resolvingSymlinksInPath().standardizedFileURL
    guard url.isFileURL,
      approvedRoots.contains(where: { url.isDescendant(of: $0) }),
      !excludedURLs.contains(where: { url.isDescendant(of: $0) }),
      Self.supportedExtensions.contains(url.pathExtension.lowercased())
    else { return false }

    let components = url.pathComponents.dropFirst().map { $0.lowercased() }
    return !components.contains(where: { $0.hasPrefix(".") })
      && Set(components).isDisjoint(with: Self.deniedComponents)
      && !components.contains(where: {
        Self.deniedPackageExtensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased())
      })
  }
}

enum LocalIndexRootPolicy {
  private static let forbiddenSystemRoots = [
    "/System", "/Library", "/private", "/usr", "/bin", "/sbin", "/etc", "/var",
    "/dev", "/cores",
  ].map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }

  static func rejectionReason(for candidate: URL) -> String? {
    let url = candidate.resolvingSymlinksInPath().standardizedFileURL
    guard url.isFileURL else { return "Only local folders can be indexed." }
    guard url.path != "/" else {
      return "Choose specific folders instead of the whole startup volume."
    }

    if forbiddenSystemRoots.contains(where: { url.isDescendant(of: $0) }) {
      return "System and private operating-system folders are excluded."
    }

    let components = url.pathComponents
    if url.path == "/Volumes"
      || (components.count == 3 && components.dropFirst().first == "Volumes")
    {
      return "Choose a folder inside the external volume instead of the volume root."
    }
    return nil
  }

  static func isAllowedRoot(_ candidate: URL) -> Bool {
    rejectionReason(for: candidate) == nil
  }

  static func allowedRoots(from candidates: [URL]) -> [URL] {
    var seen: Set<String> = []
    return candidates.compactMap { candidate in
      let url = candidate.resolvingSymlinksInPath().standardizedFileURL
      guard isAllowedRoot(url), seen.insert(url.path).inserted else { return nil }
      return url
    }
  }

  static func validate(_ roots: [URL]) throws -> [URL] {
    for root in roots {
      if let reason = rejectionReason(for: root) {
        throw LocalIndexError.forbiddenRoot(root, reason)
      }
    }
    return allowedRoots(from: roots)
  }
}

extension URL {
  fileprivate func isDescendant(of root: URL) -> Bool {
    path == root.path || path.hasPrefix(root.path.hasSuffix("/") ? root.path : root.path + "/")
  }
}
