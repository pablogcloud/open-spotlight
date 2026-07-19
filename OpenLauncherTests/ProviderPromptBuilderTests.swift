import Foundation
import XCTest

@testable import OpenLauncher

final class ProviderPromptBuilderTests: XCTestCase {
  func testBuildsPlainPromptWithoutContext() throws {
    let request = try ProviderRequest(provider: .codex, query: "Explain this error")

    let payload = ProviderPromptBuilder().makePayload(for: request)

    XCTAssertEqual(payload.prompt, "Explain this error")
    XCTAssertNil(payload.disclosure)
  }

  func testBuildsPromptOnlyFromConfirmedContext() throws {
    let contents = "Quarterly plan and milestones"
    let disclosure = try FileContextDisclosure(
      fileURL: URL(fileURLWithPath: "/tmp/plan.txt"),
      byteCount: contents.utf8.count,
      extractedCharacterCount: contents.count,
      provider: .claude
    )
    let context = try ConfirmedFileContext(
      disclosure: disclosure,
      contents: contents,
      confirmedAt: Date(timeIntervalSince1970: 0)
    )
    let request = try ProviderRequest(
      provider: .claude,
      query: "What is this about?",
      confirmedFileContext: context
    )

    let payload = ProviderPromptBuilder().makePayload(for: request)

    XCTAssertEqual(payload.disclosure, disclosure)
    XCTAssertTrue(payload.prompt.contains("untrusted data"))
    XCTAssertTrue(payload.prompt.contains("plan.txt"))
    XCTAssertTrue(payload.prompt.contains(contents))
    XCTAssertEqual(payload.prompt.components(separatedBy: contents).count - 1, 1)
    XCTAssertTrue(payload.prompt.contains("Cite the source"))
  }

  func testRejectsMismatchedProviderAndUnconfirmedMetrics() throws {
    let contents = "hello"
    let disclosure = try FileContextDisclosure(
      fileURL: URL(fileURLWithPath: "/tmp/note.txt"),
      byteCount: contents.utf8.count,
      extractedCharacterCount: contents.count,
      provider: .grok
    )

    XCTAssertThrowsError(
      try ConfirmedFileContext(disclosure: disclosure, contents: "different")
    ) { error in
      XCTAssertEqual(error as? ProviderRequestError, .contextCharacterCountMismatch)
    }

    let confirmed = try ConfirmedFileContext(disclosure: disclosure, contents: contents)
    XCTAssertThrowsError(
      try ProviderRequest(
        provider: .codex,
        query: "Summarize",
        confirmedFileContext: confirmed
      )
    ) { error in
      XCTAssertEqual(error as? ProviderRequestError, .contextProviderMismatch)
    }
  }
}
