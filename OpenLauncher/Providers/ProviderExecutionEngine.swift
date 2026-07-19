import Foundation

enum ProviderExecutionError: Error, Equatable, Sendable {
    case executableNotFound(ProviderIdentifier)
    case providerMismatch
}

final class ProviderRunSession: Sendable {
    let events: AsyncThrowingStream<NormalizedStreamEvent, any Error>
    private let cancellation: @Sendable () -> Void
    private let cancellationAndWait: @Sendable () async -> Void

    init(
        events: AsyncThrowingStream<NormalizedStreamEvent, any Error>,
        cancellation: @escaping @Sendable () -> Void,
        cancellationAndWait: @escaping @Sendable () async -> Void = {}
    ) {
        self.events = events
        self.cancellation = cancellation
        self.cancellationAndWait = cancellationAndWait
    }

    func cancel() { cancellation() }
    func cancelAndWait() async {
        cancellation()
        await cancellationAndWait()
    }
}

struct ProviderExecutionEngine: Sendable {
    private let runner: any ProcessRunning
    private let locator: ExecutableLocator
    private let promptBuilder: any ProviderPromptBuilding

    init(
        runner: any ProcessRunning = FoundationProcessRunner(),
        locator: ExecutableLocator = ExecutableLocator(),
        promptBuilder: any ProviderPromptBuilding = ProviderPromptBuilder()
    ) {
        self.runner = runner
        self.locator = locator
        self.promptBuilder = promptBuilder
    }

    func probe(_ identifier: ProviderIdentifier) async -> ProviderDescriptor {
        let adapter = ProviderAdapterFactory.make(identifier)
        guard let executableURL = locator.locate(for: adapter) else {
            return ProviderDescriptor(
                identifier: identifier,
                status: .unavailable(reason: "\(adapter.executableName) is not installed or executable."),
                capabilities: .phaseZeroRequired
            )
        }

        do {
            let invocation = try ProcessInvocation(
                executableURL: executableURL,
                arguments: adapter.versionArguments,
                environment: ProviderProcessEnvironment.make(),
                workingDirectoryURL: URL(fileURLWithPath: "/private/tmp")
            )
            let process = try await runner.start(invocation)
            var output = Data()
            var exitCode: Int32 = -1
            for try await event in process.events {
                switch event {
                case let .standardOutput(data), let .standardError(data): output.append(data)
                case let .terminated(code, _): exitCode = code
                }
            }
            guard exitCode == 0 else {
                return ProviderDescriptor(
                    identifier: identifier,
                    status: .unavailable(reason: "Version probe exited with code \(exitCode)."),
                    capabilities: .phaseZeroRequired
                )
            }
            guard await isAuthenticated(adapter: adapter, executableURL: executableURL) else {
                return ProviderDescriptor(
                    identifier: identifier,
                    status: .authenticationRequired(executableURL: executableURL),
                    capabilities: .phaseZeroRequired
                )
            }
            let version = String(decoding: output, as: UTF8.self)
                .split(whereSeparator: { $0.isNewline })
                .first
                .map(String.init)
            return ProviderDescriptor(
                identifier: identifier,
                status: .available(version: version, executableURL: executableURL),
                capabilities: .phaseZeroRequired
            )
        } catch {
            return ProviderDescriptor(
                identifier: identifier,
                status: .unavailable(reason: error.localizedDescription),
                capabilities: .phaseZeroRequired
            )
        }
    }

    private func isAuthenticated(
        adapter: any CLIProviderAdapter,
        executableURL: URL
    ) async -> Bool {
        if let authenticationFileURL = adapter.authenticationFileURL {
            return FileManager.default.isReadableFile(atPath: authenticationFileURL.path)
        }
        guard let arguments = adapter.authenticationProbeArguments else { return true }
        do {
            let invocation = try ProcessInvocation(
                executableURL: executableURL,
                arguments: arguments,
                environment: ProviderProcessEnvironment.make(),
                workingDirectoryURL: URL(fileURLWithPath: "/private/tmp")
            )
            let process = try await runner.start(invocation)
            var exitCode: Int32 = -1
            for try await event in process.events {
                if case let .terminated(code, _) = event { exitCode = code }
            }
            return exitCode == 0
        } catch {
            return false
        }
    }

    func start(_ request: ProviderRequest) async throws -> ProviderRunSession {
        let adapter = ProviderAdapterFactory.make(request.provider)
        guard adapter.identifier == request.provider else {
            throw ProviderExecutionError.providerMismatch
        }
        guard let executableURL = locator.locate(for: adapter) else {
            throw ProviderExecutionError.executableNotFound(request.provider)
        }

        let payload = promptBuilder.makePayload(for: request)
        let invocation = try adapter.makeInvocation(executableURL: executableURL, payload: payload)
        let process = try await runner.start(invocation)
        if Task.isCancelled {
            await process.cancelAndWait()
            throw CancellationError()
        }
        let state = ProviderExecutionState()

        let events = AsyncThrowingStream<NormalizedStreamEvent, any Error> { continuation in
            let task = Task {
                var lineBuffer = Data()
                var standardError = Data()
                var emittedText = false
                var sawOutputLine = false
                var pendingTerminal: NormalizedStreamEvent?

                continuation.yield(.state(.streaming))

                do {
                    for try await event in process.events {
                        switch event {
                        case let .standardOutput(data):
                            lineBuffer.append(data)
                            for line in Self.takeCompleteLines(from: &lineBuffer) {
                                sawOutputLine = true
                                for normalized in adapter.parse(line: line) {
                                    if normalized.isTerminal {
                                        if pendingTerminal == nil { pendingTerminal = normalized }
                                    } else if !state.isCancelled {
                                        if case .textDelta = normalized { emittedText = true }
                                        continuation.yield(normalized)
                                    }
                                }
                            }
                        case let .standardError(data):
                            standardError.append(data)
                        case let .terminated(exitCode, _):
                            if !lineBuffer.isEmpty {
                                let line = String(decoding: lineBuffer, as: UTF8.self)
                                sawOutputLine = !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || sawOutputLine
                                for normalized in adapter.parse(line: line) {
                                    if normalized.isTerminal {
                                        if pendingTerminal == nil { pendingTerminal = normalized }
                                    } else if !state.isCancelled {
                                        if case .textDelta = normalized { emittedText = true }
                                        continuation.yield(normalized)
                                    }
                                }
                                lineBuffer.removeAll(keepingCapacity: false)
                            }

                            if state.isCancelled {
                                continuation.yield(.state(.cancelled))
                            } else if exitCode != 0 {
                                if let pendingTerminal, case .failed = pendingTerminal {
                                    continuation.yield(pendingTerminal)
                                } else {
                                    continuation.yield(.failed(Self.failure(
                                        identifier: request.provider,
                                        exitCode: exitCode,
                                        standardError: standardError
                                    )))
                                }
                            } else if let pendingTerminal {
                                continuation.yield(pendingTerminal)
                            } else if exitCode == 0 {
                                if sawOutputLine {
                                    continuation.yield(.failed(Self.malformedOutputFailure(identifier: request.provider)))
                                } else {
                                    continuation.yield(.state(emittedText ? .completed : .empty))
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                state.markCancelled()
                process.cancel()
            }
        }

        return ProviderRunSession(
            events: events,
            cancellation: {
                state.markCancelled()
                process.cancel()
            },
            cancellationAndWait: {
                state.markCancelled()
                await process.cancelAndWait()
            }
        )
    }

    private static func takeCompleteLines(from data: inout Data) -> [String] {
        var lines: [String] = []
        while let newline = data.firstIndex(of: 0x0A) {
            let lineData = data[..<newline]
            data.removeSubrange(...newline)
            let line = String(decoding: lineData, as: UTF8.self)
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(line)
            }
        }
        return lines
    }

    private static func failure(
        identifier: ProviderIdentifier,
        exitCode: Int32,
        standardError: Data
    ) -> ProviderFailure {
        let stderr = String(decoding: standardError, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let message = stderr.isEmpty
            ? "\(identifier.displayName) exited with code \(exitCode)."
            : stderr
        let lower = message.lowercased()
        let kind: ProviderFailureKind
        if lower.contains("rate") || lower.contains("limit") || lower.contains("429") {
            kind = .rateLimited
        } else if lower.contains("auth") || lower.contains("login") || lower.contains("credential") {
            kind = .authentication
        } else if lower.contains("permission") || lower.contains("denied") {
            kind = .permissionDenied
        } else {
            kind = .invocation
        }
        return ProviderFailure(
            kind: kind,
            providerCode: "exit_\(exitCode)",
            message: message,
            isRecoverable: true
        )
    }

    private static func malformedOutputFailure(identifier: ProviderIdentifier) -> ProviderFailure {
        ProviderFailure(
            kind: .malformedOutput,
            providerCode: nil,
            message: "\(identifier.displayName) returned output Open Spotlight could not interpret.",
            isRecoverable: true
        )
    }
}

private final class ProviderExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }
    func markCancelled() { lock.withLock { cancelled = true } }
}
