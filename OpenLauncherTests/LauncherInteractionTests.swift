import XCTest

@testable import OpenLauncher

@MainActor
final class LauncherInteractionTests: XCTestCase {
  func testProviderRevealStartsWithoutASecondGlassSurface() {
    let resting = LauncherProviderRevealGeometry(progress: 0)

    XCTAssertEqual(resting.searchWidth, LauncherMetrics.surfaceWidth, accuracy: 0.001)
    XCTAssertEqual(resting.providerWidth, 0, accuracy: 0.001)
    XCTAssertEqual(resting.providerHeight, 0, accuracy: 0.001)
  }

  func testProviderRevealStaysInsideSurfaceAndFinishesWithConfiguredGap() {
    for step in 0...100 {
      let geometry = LauncherProviderRevealGeometry(progress: CGFloat(step) / 100)
      XCTAssertLessThanOrEqual(geometry.searchWidth, LauncherMetrics.surfaceWidth + 0.001)
      XCTAssertLessThanOrEqual(
        geometry.providerOffset + geometry.providerWidth,
        LauncherMetrics.surfaceWidth + 0.001
      )
      XCTAssertGreaterThanOrEqual(geometry.providerWidth, 0)
      XCTAssertGreaterThanOrEqual(geometry.providerHeight, 0)
      XCTAssertLessThanOrEqual(geometry.providerHeight, LauncherMetrics.controlSize)
      if geometry.providerWidth > 0.001 {
        XCTAssertGreaterThanOrEqual(
          geometry.providerOffset + 0.001,
          geometry.searchWidth,
          "Provider glass must grow from the seam without overlapping the search capsule"
        )
      }
    }

    let detached = LauncherProviderRevealGeometry(progress: 1)
    XCTAssertEqual(
      detached.providerOffset - detached.searchWidth,
      LauncherMetrics.providerGap,
      accuracy: 0.001
    )
  }

  func testProviderCycleHasStableOrderAndWraps() {
    XCTAssertEqual(ProviderIdentifier.claude.nextInCycle, .codex)
    XCTAssertEqual(ProviderIdentifier.codex.nextInCycle, .grok)
    XCTAssertEqual(ProviderIdentifier.grok.nextInCycle, .claude)
  }

  func testOutsideClickCannotDismissAnActiveRunOrExternalInteraction() {
    var protection = LauncherInteractionProtection()

    XCTAssertFalse(
      protection.shouldDismissOutsideClick(
        preferenceEnabled: true,
        panelVisible: true,
        hasModalWindow: false,
        clickIsInsidePanel: false,
        runState: .streaming
      ))

    protection.beginExternalInteraction()
    XCTAssertFalse(
      protection.shouldDismissOutsideClick(
        preferenceEnabled: true,
        panelVisible: true,
        hasModalWindow: false,
        clickIsInsidePanel: false,
        runState: .failed
      ))
  }

  func testOutsideClickDismissesIdlePanelWhenUnprotected() {
    let protection = LauncherInteractionProtection()

    XCTAssertTrue(
      protection.shouldDismissOutsideClick(
        preferenceEnabled: true,
        panelVisible: true,
        hasModalWindow: false,
        clickIsInsidePanel: false,
        runState: .ready
      ))
  }

  func testExternalInteractionOnlyCompletesAfterApplicationRoundTrip() {
    var protection = LauncherInteractionProtection()
    protection.beginExternalInteraction()

    XCTAssertFalse(protection.applicationDidBecomeActive())
    protection.applicationDidResignActive()
    XCTAssertTrue(protection.applicationDidBecomeActive())
    XCTAssertFalse(protection.isExternalInteractionInProgress)
  }
}
