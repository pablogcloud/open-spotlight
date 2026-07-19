import CoreServices
import Foundation
import UniformTypeIdentifiers

protocol SpotlightMetadataSearching: Sendable {
  func search(_ query: String, limit: Int) async -> [LauncherSuggestion]
}

actor SpotlightMetadataSuggestionSource: SpotlightMetadataSearching {
  func search(_ query: String, limit: Int) -> [LauncherSuggestion] {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard term.count >= 1, limit > 0 else { return [] }

    let escaped =
      term
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let expression = "kMDItemFSName == \"*\(escaped)*\"cd"
    guard
      let metadataQuery = MDQueryCreate(
        kCFAllocatorDefault,
        expression as CFString,
        nil,
        [kMDItemFSName, kMDItemLastUsedDate] as CFArray
      )
    else { return [] }

    MDQuerySetSearchScope(
      metadataQuery,
      [kMDQueryScopeHome, "/Applications" as CFString, "/System/Applications" as CFString]
        as CFArray,
      0
    )
    guard MDQueryExecute(metadataQuery, CFOptionFlags(kMDQuerySynchronous.rawValue)) else {
      return []
    }

    let normalized = term.lowercased()
    let resultCount = min(MDQueryGetResultCount(metadataQuery), 5_000)
    var seen = Set<String>()
    var suggestions: [LauncherSuggestion] = []

    for index in 0..<resultCount {
      let rawResult = MDQueryGetResultAtIndex(metadataQuery, index)
      let item = unsafeBitCast(rawResult, to: MDItem.self)
      guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String else { continue }
      let url = URL(fileURLWithPath: path).standardizedFileURL
      guard isUsefulResult(url), seen.insert(url.path).inserted else { continue }

      let title = url.deletingPathExtension().lastPathComponent
      let lowerTitle = title.lowercased()
      let matchScore: Double
      if lowerTitle == normalized {
        matchScore = 1_000
      } else if lowerTitle.hasPrefix(normalized) {
        matchScore = 940
      } else {
        matchScore = 860
      }

      let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
      let isApplication = url.pathExtension.lowercased() == "app"
      let isDirectory = resourceValues?.isDirectory == true
      let kind: LauncherSuggestionKind =
        isApplication ? .application : (isDirectory ? .folder : .file)
      let subtitle =
        isApplication
        ? "Application"
        : url.deletingLastPathComponent().lastPathComponent

      suggestions.append(
        LauncherSuggestion(
          id: "metadata:\(url.path)",
          kind: kind,
          title: title,
          subtitle: subtitle,
          icon: .file(url),
          action: .open(url),
          score: matchScore + (isApplication ? 30 : 0)
        ))
    }

    return
      suggestions
      .sorted {
        if $0.score == $1.score {
          return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        return $0.score > $1.score
      }
      .prefix(limit)
      .map { $0 }
  }

  private func isUsefulResult(_ url: URL) -> Bool {
    guard !url.lastPathComponent.hasPrefix("."),
      !url.path.contains("/.Trash/"),
      !url.path.contains("/Library/Caches/")
    else { return false }

    let appComponents = url.pathComponents.filter { $0.lowercased().hasSuffix(".app") }
    return appComponents.isEmpty || url.pathExtension.lowercased() == "app"
  }
}
