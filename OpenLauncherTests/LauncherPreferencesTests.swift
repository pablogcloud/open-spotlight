import Foundation
import XCTest

@testable import OpenLauncher

@MainActor
final class LauncherPreferencesTests: XCTestCase {
  func testFreshPreferencesUseLauncherDefaults() {
    withIsolatedDefaults { defaults in
      let preferences = LauncherPreferences(defaults: defaults)

      XCTAssertEqual(preferences.defaultProvider, .codex)
      XCTAssertEqual(preferences.placement, .spotlight)
      XCTAssertEqual(preferences.resultSize, .comfortable)
      XCTAssertEqual(preferences.glassContrast, .standard)
      XCTAssertTrue(preferences.clearQueryOnOpen)
      XCTAssertTrue(preferences.revealProviderOnHover)
      XCTAssertTrue(preferences.dismissOnOutsideClick)
      XCTAssertFalse(preferences.reduceMotion)
      XCTAssertTrue(preferences.indexedFolderPaths.isEmpty)
    }
  }

  func testPreferencesPersistAcrossInstances() {
    withIsolatedDefaults { defaults in
      let preferences = LauncherPreferences(defaults: defaults)
      preferences.defaultProvider = .grok
      preferences.placement = .center
      preferences.resultSize = .spacious
      preferences.glassContrast = .increased
      preferences.clearQueryOnOpen = false
      preferences.revealProviderOnHover = false
      preferences.dismissOnOutsideClick = false
      preferences.reduceMotion = true
      preferences.indexedFolderPaths = ["/tmp/Documents"]

      let reloaded = LauncherPreferences(defaults: defaults)
      XCTAssertEqual(reloaded.defaultProvider, .grok)
      XCTAssertEqual(reloaded.placement, .center)
      XCTAssertEqual(reloaded.resultSize, .spacious)
      XCTAssertEqual(reloaded.glassContrast, .increased)
      XCTAssertFalse(reloaded.clearQueryOnOpen)
      XCTAssertFalse(reloaded.revealProviderOnHover)
      XCTAssertFalse(reloaded.dismissOnOutsideClick)
      XCTAssertTrue(reloaded.reduceMotion)
      XCTAssertEqual(reloaded.indexedFolderPaths, ["/tmp/Documents"])
    }
  }

  func testForbiddenPersistedRootMovesToPendingQuarantine() {
    withIsolatedDefaults { defaults in
      defaults.set(["/", "/tmp/Documents"], forKey: "indexedFolderPaths")

      let preferences = LauncherPreferences(defaults: defaults)

      XCTAssertEqual(preferences.indexedFolderPaths, ["/tmp/Documents"])
      XCTAssertEqual(preferences.pendingLegacyIndexQuarantinePaths, ["/"])
      XCTAssertEqual(defaults.stringArray(forKey: "indexedFolderPaths"), ["/tmp/Documents"])
    }
  }

  func testPendingQuarantineSurvivesRelaunchUntilCompleted() {
    withIsolatedDefaults { defaults in
      defaults.set(["/"], forKey: "indexedFolderPaths")
      let first = LauncherPreferences(defaults: defaults)
      XCTAssertEqual(first.pendingLegacyIndexQuarantinePaths, ["/"])

      let second = LauncherPreferences(defaults: defaults)
      XCTAssertEqual(second.pendingLegacyIndexQuarantinePaths, ["/"])

      second.completeLegacyIndexQuarantine()
      let completed = LauncherPreferences(defaults: defaults)
      XCTAssertTrue(completed.pendingLegacyIndexQuarantinePaths.isEmpty)
    }
  }

  func testSpotlightPlacementMatchesMeasuredNativeFrame() {
    let screenFrame = CGRect(x: 0, y: 0, width: 1_728, height: 1_117)
    let panelSize = CGSize(width: 640, height: 56)

    let origin = LauncherPlacement.spotlight.panelOrigin(in: screenFrame, panelSize: panelSize)

    XCTAssertEqual(origin.x, 544, accuracy: 0.5)
    XCTAssertEqual(origin.y, 790, accuracy: 0.5)
    XCTAssertEqual(screenFrame.maxY - origin.y - panelSize.height, 271, accuracy: 0.5)
  }

  func testSuggestionExpansionPreservesSpotlightTopAnchorDuringOpening() {
    let openingFrame = CGRect(x: 544, y: 780, width: 640, height: 56)

    let expanded = LauncherPanelGeometry.resizedFrame(
      from: openingFrame,
      toHeight: 234,
      anchoredTopY: 846
    )

    XCTAssertEqual(expanded.origin.y, 612, accuracy: 0.5)
    XCTAssertEqual(expanded.maxY, 846, accuracy: 0.5)
  }

  private func withIsolatedDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "OpenSpotlightTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    body(defaults)
  }
}
