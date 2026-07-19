import XCTest
@testable import OpenLauncher

final class ProviderModelsTests: XCTestCase {
    func testAllLaunchProvidersAreRepresented() {
        XCTAssertEqual(ProviderIdentifier.allCases, [.claude, .codex, .grok])
        XCTAssertEqual(ProviderIdentifier.claude.displayName, "Claude")
        XCTAssertEqual(ProviderIdentifier.codex.displayName, "Codex")
        XCTAssertEqual(ProviderIdentifier.grok.displayName, "Grok")
    }

    func testRequiredCapabilitiesContainEveryPhaseZeroCapability() {
        let capabilities = ProviderCapabilities.phaseZeroRequired

        XCTAssertTrue(capabilities.contains(.versionProbe))
        XCTAssertTrue(capabilities.contains(.streaming))
        XCTAssertTrue(capabilities.contains(.cancellation))
        XCTAssertTrue(capabilities.contains(.fileContext))
    }

    func testTerminalStateAndEventClassification() {
        XCTAssertFalse(ProviderRunState.streaming.isTerminal)
        XCTAssertTrue(ProviderRunState.cancelled.isTerminal)
        XCTAssertFalse(NormalizedStreamEvent.textDelta("partial").isTerminal)
        XCTAssertTrue(NormalizedStreamEvent.completed(.init(exitCode: 0)).isTerminal)
    }

    func testRateLimitFailureCanPreserveProviderCode() {
        let failure = ProviderFailure(
            kind: .rateLimited,
            providerCode: "monthly_spend_limit",
            message: "Monthly limit reached",
            isRecoverable: true
        )

        XCTAssertEqual(failure.kind, .rateLimited)
        XCTAssertEqual(failure.providerCode, "monthly_spend_limit")
        XCTAssertTrue(NormalizedStreamEvent.failed(failure).isTerminal)
    }
}
