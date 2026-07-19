import Foundation
import XCTest

@testable import OpenLauncher

final class ProviderAdapterTests: XCTestCase {
  func testClaudeParsesDeltaCompletionAndRateLimit() {
    let adapter = ClaudeAdapter()
    let delta = adapter.parse(
      line:
        #"{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"Ready"}}}"#
    )
    let completion = adapter.parse(line: #"{"type":"result","subtype":"success","is_error":false}"#)
    let rateLimit = adapter.parse(
      line:
        #"{"type":"assistant","error":"rate_limit","message":{"content":[{"type":"text","text":"Monthly spend limit reached"}]}}"#
    )

    XCTAssertEqual(delta, [.textDelta("Ready")])
    XCTAssertEqual(completion, [.completed(.init(exitCode: 0))])
    guard case .failed(let failure) = rateLimit.first else {
      return XCTFail("Expected normalized failure")
    }
    XCTAssertEqual(failure.kind, .rateLimited)
    XCTAssertEqual(failure.providerCode, "rate_limit")
  }

  func testCodexParsesAgentMessageAndIgnoresNonterminalWarningItem() {
    let adapter = CodexAdapter()
    let warning = adapter.parse(
      line: #"{"type":"item.completed","item":{"type":"error","message":"warning"}}"#)
    let message = adapter.parse(
      line: #"{"type":"item.completed","item":{"type":"agent_message","text":"READY"}}"#)
    let completion = adapter.parse(line: #"{"type":"turn.completed","usage":{}}"#)

    XCTAssertTrue(warning.isEmpty)
    XCTAssertEqual(message, [.textDelta("READY")])
    XCTAssertEqual(completion, [.completed(.init(exitCode: 0))])
  }

  func testGrokParsesTextAndEndWhileIgnoringThoughts() {
    let adapter = GrokAdapter()

    XCTAssertTrue(adapter.parse(line: #"{"type":"thought","data":"thinking"}"#).isEmpty)
    XCTAssertEqual(
      adapter.parse(line: #"{"type":"text","data":"READY"}"#),
      [.textDelta("READY")]
    )
    XCTAssertEqual(
      adapter.parse(line: #"{"type":"end","stopReason":"EndTurn"}"#),
      [.completed(.init(exitCode: 0))]
    )
  }

  func testInvocationsPassPromptAsOneArgumentAndExposeEffectivePermissions() throws {
    let executable = URL(fileURLWithPath: "/usr/bin/true")
    let payload = ProviderPayload(prompt: "hello; touch /tmp/never", disclosure: nil)
    let claude = ClaudeAdapter()
    let codex = CodexAdapter()
    let grok = GrokAdapter()

    let claudeInvocation = try claude.makeInvocation(executableURL: executable, payload: payload)
    let codexInvocation = try codex.makeInvocation(executableURL: executable, payload: payload)
    let grokInvocation = try grok.makeInvocation(executableURL: executable, payload: payload)

    XCTAssertFalse(claudeInvocation.arguments.contains(payload.prompt))
    XCTAssertEqual(claudeInvocation.standardInput, Data(payload.prompt.utf8))
    XCTAssertTrue(claudeInvocation.arguments.contains("--safe-mode"))
    XCTAssertTrue(claude.invocationDisclosure.launcherDisablesTools)

    XCTAssertFalse(codexInvocation.arguments.contains(payload.prompt))
    XCTAssertEqual(codexInvocation.arguments.last, "-")
    XCTAssertEqual(codexInvocation.standardInput, Data(payload.prompt.utf8))
    XCTAssertTrue(codexInvocation.arguments.contains("read-only"))
    XCTAssertFalse(codex.invocationDisclosure.launcherDisablesTools)
    XCTAssertNotNil(codex.invocationDisclosure.residualAccess)

    XCTAssertFalse(grokInvocation.arguments.contains(payload.prompt))
    XCTAssertEqual(grokInvocation.standardInput, Data(payload.prompt.utf8))
    XCTAssertTrue(grokInvocation.arguments.contains("/dev/stdin"))
    XCTAssertTrue(grokInvocation.arguments.contains("--disable-web-search"))
    XCTAssertTrue(grok.invocationDisclosure.launcherDisablesTools)
    XCTAssertNotEqual(
      grokInvocation.environment?["HOME"], FileManager.default.homeDirectoryForCurrentUser.path)
    XCTAssertEqual(
      grokInvocation.environment?["GROK_AUTH_PATH"],
      FileManager.default.homeDirectoryForCurrentUser.appending(path: ".grok/auth.json").path
    )
  }

  func testMalformedLinesDoNotCrashParsers() {
    for identifier in ProviderIdentifier.allCases {
      XCTAssertTrue(ProviderAdapterFactory.make(identifier).parse(line: "not-json").isEmpty)
    }
  }

  func testProviderEnvironmentDropsAmbientCredentialsEndpointsAndNestingState() {
    let environment = ProviderProcessEnvironment.make(baseEnvironment: [
      "HOME": "/Users/tester",
      "USER": "tester",
      "PATH": "/custom/bin",
      "ANTHROPIC_API_KEY": "secret",
      "OPENAI_API_KEY": "secret",
      "XAI_API_KEY": "secret",
      "OPENAI_BASE_URL": "https://proxy.example",
      "HTTPS_PROXY": "https://proxy.example",
      "CLAUDECODE": "1",
      "CODEX_THREAD_ID": "thread",
    ])

    XCTAssertEqual(environment["HOME"], "/Users/tester")
    XCTAssertEqual(environment["USER"], "tester")
    XCTAssertTrue(environment["PATH", default: ""].contains("/custom/bin"))
    XCTAssertNil(environment["ANTHROPIC_API_KEY"])
    XCTAssertNil(environment["OPENAI_API_KEY"])
    XCTAssertNil(environment["XAI_API_KEY"])
    XCTAssertNil(environment["OPENAI_BASE_URL"])
    XCTAssertNil(environment["HTTPS_PROXY"])
    XCTAssertNil(environment["CLAUDECODE"])
    XCTAssertNil(environment["CODEX_THREAD_ID"])
  }
}
