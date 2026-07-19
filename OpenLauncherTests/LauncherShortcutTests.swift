import Foundation
import XCTest

@testable import OpenLauncher

final class LauncherShortcutTests: XCTestCase {
  func testShortcutChoicePersistsAndDefaultsToOptionSpace() {
    let suiteName = "org.openlauncher.tests.shortcut.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      return XCTFail("Expected isolated user defaults")
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    XCTAssertEqual(LauncherShortcut.stored(in: defaults), .optionSpace)
    for shortcut in LauncherShortcut.allCases {
      shortcut.persist(in: defaults)
      XCTAssertEqual(LauncherShortcut.stored(in: defaults), shortcut)
    }
  }
}
