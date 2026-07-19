import Foundation
import Darwin
import XCTest
@testable import OpenLauncher

final class ProviderExecutionEngineTests: XCTestCase {
    func testEngineBuffersSplitJSONLinesAndNormalizesTerminalEvent() async throws {
        let first = Data(#"{"type":"item.completed","item":{"type":"agent_"#.utf8)
        let second = Data("message\",\"text\":\"Hello\"}}\n{\"type\":\"turn.completed\"}\n".utf8)
        let runner = FixtureProcessRunner(events: [
            .standardOutput(first),
            .standardOutput(second),
            .terminated(exitCode: 0, reason: .exit),
        ])
        let engine = ProviderExecutionEngine(
            runner: runner,
            locator: fixtureLocator(for: .codex)
        )
        let request = try ProviderRequest(provider: .codex, query: "Hello")
        let session = try await engine.start(request)
        var events: [NormalizedStreamEvent] = []

        for try await event in session.events { events.append(event) }

        XCTAssertEqual(events, [
            .state(.streaming),
            .textDelta("Hello"),
            .completed(.init(exitCode: 0)),
        ])
    }

    func testEngineClassifiesNonzeroStderrWithoutStructuredFailure() async throws {
        let runner = FixtureProcessRunner(events: [
            .standardError(Data("authentication required".utf8)),
            .terminated(exitCode: 1, reason: .exit),
        ])
        let engine = ProviderExecutionEngine(
            runner: runner,
            locator: fixtureLocator(for: .grok)
        )
        let request = try ProviderRequest(provider: .grok, query: "Hello")
        let session = try await engine.start(request)
        var failure: ProviderFailure?

        for try await event in session.events {
            if case let .failed(value) = event { failure = value }
        }

        XCTAssertEqual(failure?.kind, .authentication)
        XCTAssertEqual(failure?.providerCode, "exit_1")
    }

    func testClaudeStructuredErrorSequenceEmitsOneTerminalEvent() async throws {
        let runner = FixtureProcessRunner(events: [
            .standardOutput(Data((#"{"type":"assistant","error":"rate_limit","message":{"content":[{"type":"text","text":"Limit reached"}]}}"# + "\n").utf8)),
            .standardOutput(Data((#"{"type":"result","is_error":true,"result":"Limit reached","terminal_reason":"api_error"}"# + "\n").utf8)),
            .terminated(exitCode: 0, reason: .exit),
        ])
        let engine = ProviderExecutionEngine(runner: runner, locator: fixtureLocator(for: .claude))
        let request = try ProviderRequest(provider: .claude, query: "Hello")
        let session = try await engine.start(request)
        var events: [NormalizedStreamEvent] = []

        for try await event in session.events { events.append(event) }

        XCTAssertEqual(events.filter(\.isTerminal).count, 1)
        guard case let .failed(failure) = events.last else { return XCTFail("Expected terminal failure") }
        XCTAssertEqual(failure.kind, .rateLimited)
    }

    func testCancellationWinsOverBufferedProviderCompletion() async throws {
        let runner = CancellationFixtureRunner()
        let engine = ProviderExecutionEngine(runner: runner, locator: fixtureLocator(for: .grok))
        let request = try ProviderRequest(provider: .grok, query: "Hello")
        let session = try await engine.start(request)

        session.cancel()
        var events: [NormalizedStreamEvent] = []
        for try await event in session.events { events.append(event) }

        XCTAssertEqual(events.filter(\.isTerminal), [.state(.cancelled)])
    }

    func testProbeUsesFakeExecutableAndReportsVersion() async {
        let runner = FixtureProcessRunner(events: [
            .standardOutput(Data("codex-cli 9.9\n".utf8)),
            .terminated(exitCode: 0, reason: .exit),
        ])
        let engine = ProviderExecutionEngine(runner: runner, locator: fixtureLocator(for: .codex))

        let descriptor = await engine.probe(.codex)

        guard case let .available(version, executable) = descriptor.status else {
            return XCTFail("Expected fake provider to be available")
        }
        XCTAssertEqual(version, "codex-cli 9.9")
        XCTAssertEqual(executable.path, "/usr/bin/true")
    }

    func testProbeReportsMissingExecutableWithoutUsingHostInstallation() async {
        let engine = ProviderExecutionEngine(
            runner: FixtureProcessRunner(events: []),
            locator: ExecutableLocator(environmentPath: "", includeDefaultCandidates: false)
        )

        let descriptor = await engine.probe(.codex)

        guard case .unavailable = descriptor.status else {
            return XCTFail("Expected unavailable status")
        }
    }

    func testProbeReportsAuthenticationRequiredWhenLoginStatusFails() async {
        let runner = SequencedFixtureProcessRunner(sequences: [
            [
                .standardOutput(Data("codex-cli 9.9\n".utf8)),
                .terminated(exitCode: 0, reason: .exit),
            ],
            [
                .standardError(Data("Not logged in\n".utf8)),
                .terminated(exitCode: 1, reason: .exit),
            ],
        ])
        let engine = ProviderExecutionEngine(runner: runner, locator: fixtureLocator(for: .codex))

        let descriptor = await engine.probe(.codex)

        guard case let .authenticationRequired(executableURL) = descriptor.status else {
            return XCTFail("Expected authentication-required status")
        }
        XCTAssertEqual(executableURL.path, "/usr/bin/true")
    }

    func testOneProviderFailureDoesNotPoisonNextProviderRun() async throws {
        let runner = SequencedFixtureProcessRunner(sequences: [
            [
                .standardError(Data("authentication required".utf8)),
                .terminated(exitCode: 1, reason: .exit),
            ],
            [
                .standardOutput(Data((#"{"type":"text","data":"READY"}"# + "\n").utf8)),
                .standardOutput(Data((#"{"type":"end"}"# + "\n").utf8)),
                .terminated(exitCode: 0, reason: .exit),
            ],
        ])
        let locator = ExecutableLocator(
            environmentPath: "",
            includeDefaultCandidates: false,
            explicitExecutables: [
                .codex: URL(fileURLWithPath: "/usr/bin/true"),
                .grok: URL(fileURLWithPath: "/usr/bin/true"),
            ]
        )
        let engine = ProviderExecutionEngine(runner: runner, locator: locator)

        let failed = try await engine.start(ProviderRequest(provider: .codex, query: "one"))
        var firstTerminal: NormalizedStreamEvent?
        for try await event in failed.events where event.isTerminal { firstTerminal = event }

        let succeeded = try await engine.start(ProviderRequest(provider: .grok, query: "two"))
        var secondEvents: [NormalizedStreamEvent] = []
        for try await event in succeeded.events { secondEvents.append(event) }

        guard case .failed = firstTerminal else { return XCTFail("Expected first provider failure") }
        XCTAssertTrue(secondEvents.contains(.textDelta("READY")))
        XCTAssertEqual(secondEvents.filter(\.isTerminal), [.completed(.init(exitCode: 0))])
    }

    func testNonzeroExitOverridesStructuredSuccess() async throws {
        let runner = FixtureProcessRunner(events: [
            .standardOutput(Data((#"{"type":"text","data":"partial"}"# + "\n").utf8)),
            .standardOutput(Data((#"{"type":"end"}"# + "\n").utf8)),
            .standardError(Data("wrapper failed".utf8)),
            .terminated(exitCode: 1, reason: .exit),
        ])
        let engine = ProviderExecutionEngine(runner: runner, locator: fixtureLocator(for: .grok))
        let request = try ProviderRequest(provider: .grok, query: "Hello")
        let session = try await engine.start(request)
        var terminal: NormalizedStreamEvent?

        for try await event in session.events where event.isTerminal { terminal = event }

        guard case let .failed(failure) = terminal else { return XCTFail("Expected nonzero exit failure") }
        XCTAssertEqual(failure.providerCode, "exit_1")
        XCTAssertEqual(failure.message, "wrapper failed")
    }
}

private func fixtureLocator(for provider: ProviderIdentifier) -> ExecutableLocator {
    ExecutableLocator(
        environmentPath: "",
        includeDefaultCandidates: false,
        explicitExecutables: [provider: URL(fileURLWithPath: "/usr/bin/true")]
    )
}

private struct FixtureProcessRunner: ProcessRunning {
    let outputEvents: [ProcessOutputEvent]

    init(events: [ProcessOutputEvent]) {
        outputEvents = events
    }

    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession {
        let stream = AsyncThrowingStream<ProcessOutputEvent, any Error> { continuation in
            for event in outputEvents { continuation.yield(event) }
            continuation.finish()
        }
        return ProcessSession(events: stream, cancellation: {}, runningCheck: { false })
    }
}

private final class CancellationFixtureRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<ProcessOutputEvent, any Error>.Continuation?

    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession {
        let stream = AsyncThrowingStream<ProcessOutputEvent, any Error> { continuation in
            lock.withLock { self.continuation = continuation }
        }
        return ProcessSession(
            events: stream,
            cancellation: { [weak self] in self?.finishCancellation() },
            runningCheck: { true }
        )
    }

    private func finishCancellation() {
        let continuation = lock.withLock { self.continuation }
        continuation?.yield(.standardOutput(Data((#"{"type":"end"}"# + "\n").utf8)))
        continuation?.yield(.terminated(exitCode: SIGTERM, reason: .uncaughtSignal))
        continuation?.finish()
    }
}

private final class SequencedFixtureProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var sequences: [[ProcessOutputEvent]]

    init(sequences: [[ProcessOutputEvent]]) { self.sequences = sequences }

    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession {
        let events = lock.withLock { sequences.isEmpty ? [] : sequences.removeFirst() }
        let stream = AsyncThrowingStream<ProcessOutputEvent, any Error> { continuation in
            events.forEach { continuation.yield($0) }
            continuation.finish()
        }
        return ProcessSession(events: stream, cancellation: {}, runningCheck: { false })
    }
}
