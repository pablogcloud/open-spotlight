import Foundation
import Observation

enum LauncherPlacement: String, CaseIterable, Identifiable, Sendable {
  case spotlight = "upperThird"
  case center

  var id: Self { self }

  var title: String {
    switch self {
    case .spotlight: "Spotlight"
    case .center: "Center"
    }
  }

  func panelOrigin(in screenFrame: CGRect, panelSize: CGSize) -> CGPoint {
    let x = screenFrame.midX - panelSize.width / 2
    let y: CGFloat
    switch self {
    case .spotlight:
      // Native Spotlight measured at a 271 pt top inset on a 1,117 pt display.
      let topInset = screenFrame.height * (271.0 / 1_117.0)
      y = screenFrame.maxY - panelSize.height - topInset
    case .center:
      y = screenFrame.midY - panelSize.height / 2
    }
    return CGPoint(x: x, y: y)
  }
}

enum LauncherResultSize: String, CaseIterable, Identifiable, Sendable {
  case compact
  case comfortable
  case spacious

  var id: Self { self }

  var title: String {
    switch self {
    case .compact: "Compact"
    case .comfortable: "Comfortable"
    case .spacious: "Spacious"
    }
  }

  var height: CGFloat {
    switch self {
    case .compact: 310
    case .comfortable: 390
    case .spacious: 510
    }
  }
}

enum LauncherGlassContrast: String, CaseIterable, Identifiable, Sendable {
  case standard
  case increased

  var id: Self { self }

  var title: String {
    switch self {
    case .standard: "Standard"
    case .increased: "Increased"
    }
  }
}

@Observable
@MainActor
final class LauncherPreferences {
  private enum Key {
    static let defaultProvider = "defaultProvider"
    static let placement = "launcherPlacement"
    static let resultSize = "launcherResultSize"
    static let glassContrast = "launcherGlassContrast"
    static let clearQueryOnOpen = "clearQueryOnOpen"
    static let revealProviderOnHover = "revealProviderOnHover"
    static let dismissOnOutsideClick = "dismissOnOutsideClick"
    static let reduceMotion = "reduceLauncherMotion"
    static let indexedFolderPaths = "indexedFolderPaths"
    static let pendingLegacyIndexQuarantinePaths = "pendingLegacyIndexQuarantinePaths"
  }

  private let defaults: UserDefaults

  var defaultProvider: ProviderIdentifier {
    didSet { persist(defaultProvider.rawValue, key: Key.defaultProvider) }
  }
  var placement: LauncherPlacement { didSet { persist(placement.rawValue, key: Key.placement) } }
  var resultSize: LauncherResultSize {
    didSet { persist(resultSize.rawValue, key: Key.resultSize) }
  }
  var glassContrast: LauncherGlassContrast {
    didSet { persist(glassContrast.rawValue, key: Key.glassContrast) }
  }
  var clearQueryOnOpen: Bool { didSet { persist(clearQueryOnOpen, key: Key.clearQueryOnOpen) } }
  var revealProviderOnHover: Bool {
    didSet { persist(revealProviderOnHover, key: Key.revealProviderOnHover) }
  }
  var dismissOnOutsideClick: Bool {
    didSet { persist(dismissOnOutsideClick, key: Key.dismissOnOutsideClick) }
  }
  var reduceMotion: Bool { didSet { persist(reduceMotion, key: Key.reduceMotion) } }
  var indexedFolderPaths: [String] {
    didSet { persist(indexedFolderPaths, key: Key.indexedFolderPaths) }
  }
  private(set) var pendingLegacyIndexQuarantinePaths: [String]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    defaultProvider =
      defaults.string(forKey: Key.defaultProvider)
      .flatMap(ProviderIdentifier.init(rawValue:)) ?? .codex
    placement =
      defaults.string(forKey: Key.placement)
      .flatMap(LauncherPlacement.init(rawValue:)) ?? .spotlight
    resultSize =
      defaults.string(forKey: Key.resultSize)
      .flatMap(LauncherResultSize.init(rawValue:)) ?? .comfortable
    glassContrast =
      defaults.string(forKey: Key.glassContrast)
      .flatMap(LauncherGlassContrast.init(rawValue:)) ?? .standard
    clearQueryOnOpen = defaults.object(forKey: Key.clearQueryOnOpen) as? Bool ?? true
    revealProviderOnHover = defaults.object(forKey: Key.revealProviderOnHover) as? Bool ?? true
    dismissOnOutsideClick = defaults.object(forKey: Key.dismissOnOutsideClick) as? Bool ?? true
    reduceMotion = defaults.object(forKey: Key.reduceMotion) as? Bool ?? false
    let storedPaths = defaults.stringArray(forKey: Key.indexedFolderPaths) ?? []
    let alreadyPending = defaults.stringArray(forKey: Key.pendingLegacyIndexQuarantinePaths) ?? []
    let partitioned = Self.partitionIndexPaths(storedPaths)
    indexedFolderPaths = partitioned.allowed
    pendingLegacyIndexQuarantinePaths = Array(Set(alreadyPending + partitioned.forbidden)).sorted()
    defaults.set(indexedFolderPaths, forKey: Key.indexedFolderPaths)
    defaults.set(pendingLegacyIndexQuarantinePaths, forKey: Key.pendingLegacyIndexQuarantinePaths)
  }

  var indexedFolders: [URL] {
    LocalIndexRootPolicy.allowedRoots(
      from: indexedFolderPaths.map {
        URL(fileURLWithPath: $0, isDirectory: true)
      })
  }

  func completeLegacyIndexQuarantine() {
    pendingLegacyIndexQuarantinePaths = []
    defaults.set([], forKey: Key.pendingLegacyIndexQuarantinePaths)
  }

  private func persist(_ value: Any, key: String) {
    defaults.set(value, forKey: key)
  }

  private static func partitionIndexPaths(_ paths: [String]) -> (
    allowed: [String], forbidden: [String]
  ) {
    var allowed: Set<String> = []
    var forbidden: Set<String> = []
    for path in paths {
      let url = URL(fileURLWithPath: path, isDirectory: true)
        .resolvingSymlinksInPath().standardizedFileURL
      if LocalIndexRootPolicy.isAllowedRoot(url) {
        allowed.insert(url.path)
      } else {
        forbidden.insert(url.path)
      }
    }
    return (allowed.sorted(), forbidden.sorted())
  }
}
