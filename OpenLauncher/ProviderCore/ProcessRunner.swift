@preconcurrency import Foundation
import Darwin

struct ProcessInvocation: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
    let environment: [String: String]?
    let workingDirectoryURL: URL?
    let standardInput: Data?
    let terminationGracePeriod: Duration

    init(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectoryURL: URL? = nil,
        standardInput: Data? = nil,
        terminationGracePeriod: Duration = .milliseconds(250)
    ) throws {
        guard executableURL.isFileURL, executableURL.path.hasPrefix("/") else {
            throw ProcessRunnerError.executableMustBeAnAbsoluteFileURL
        }
        if let workingDirectoryURL,
           (!workingDirectoryURL.isFileURL || !workingDirectoryURL.path.hasPrefix("/")) {
            throw ProcessRunnerError.workingDirectoryMustBeAnAbsoluteFileURL
        }

        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.workingDirectoryURL = workingDirectoryURL
        self.standardInput = standardInput
        self.terminationGracePeriod = terminationGracePeriod
    }
}

enum ProcessTerminationReason: Equatable, Sendable {
    case exit
    case uncaughtSignal
}

enum ProcessOutputEvent: Equatable, Sendable {
    case standardOutput(Data)
    case standardError(Data)
    case terminated(exitCode: Int32, reason: ProcessTerminationReason)
}

enum ProcessRunnerError: Error, Equatable, Sendable {
    case executableMustBeAnAbsoluteFileURL
    case workingDirectoryMustBeAnAbsoluteFileURL
    case launchFailed(String)
}

protocol ProcessRunning: Sendable {
    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession
}

final class ProcessSession: Sendable {
    let events: AsyncThrowingStream<ProcessOutputEvent, any Error>
    private let cancellation: @Sendable () -> Void
    private let cancellationAndWait: @Sendable () async -> Void
    private let runningCheck: @Sendable () -> Bool

    init(
        events: AsyncThrowingStream<ProcessOutputEvent, any Error>,
        cancellation: @escaping @Sendable () -> Void,
        runningCheck: @escaping @Sendable () -> Bool,
        cancellationAndWait: @escaping @Sendable () async -> Void = {}
    ) {
        self.events = events
        self.cancellation = cancellation
        self.runningCheck = runningCheck
        self.cancellationAndWait = cancellationAndWait
    }

    var isRunning: Bool { runningCheck() }

    func cancel() {
        cancellation()
    }

    func cancelAndWait() async {
        cancellation()
        await cancellationAndWait()
    }
}

struct FoundationProcessRunner: ProcessRunning {
    func start(_ invocation: ProcessInvocation) async throws -> ProcessSession {
        let process = Process()
        process.executableURL = invocation.executableURL
        process.arguments = invocation.arguments
        process.environment = invocation.environment
        process.currentDirectoryURL = invocation.workingDirectoryURL

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        let state = ProcessState(
            process: process,
            gracePeriod: invocation.terminationGracePeriod
        )

        let events = AsyncThrowingStream<ProcessOutputEvent, any Error> { continuation in
            let emitter = ProcessOutputEmitter(
                continuation: continuation,
                outputPipe: outputPipe,
                errorPipe: errorPipe
            )
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                emitter.receive(handle.availableData, standardError: false)
            }
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                emitter.receive(handle.availableData, standardError: true)
            }
            process.terminationHandler = { terminatedProcess in
                terminatedProcess.terminationHandler = nil
                state.markTerminated()
                let reason: ProcessTerminationReason = terminatedProcess.terminationReason == .exit
                    ? .exit
                    : .uncaughtSignal
                emitter.processTerminated(
                    exitCode: terminatedProcess.terminationStatus,
                    reason: reason
                )
            }
            continuation.onTermination = { @Sendable termination in
                if case .cancelled = termination {
                    state.cancel()
                }
            }
        }

        do {
            try process.run()
            state.markRunning()
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            process.terminationHandler = nil
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        if let standardInput = invocation.standardInput {
            try? inputPipe.fileHandleForWriting.write(contentsOf: standardInput)
        }
        try? inputPipe.fileHandleForWriting.close()

        return ProcessSession(
            events: events,
            cancellation: { state.cancel() },
            runningCheck: { state.isRunning },
            cancellationAndWait: { await state.waitForCancellation() }
        )
    }
}

private final class ProcessOutputEmitter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "org.openlauncher.process-output")
    private let continuation: AsyncThrowingStream<ProcessOutputEvent, any Error>.Continuation
    private let outputPipe: Pipe
    private let errorPipe: Pipe
    private var finished = false
    private var outputReachedEOF = false
    private var errorReachedEOF = false
    private var termination: (exitCode: Int32, reason: ProcessTerminationReason)?

    init(
        continuation: AsyncThrowingStream<ProcessOutputEvent, any Error>.Continuation,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) {
        self.continuation = continuation
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
    }

    func receive(_ data: Data, standardError: Bool) {
        queue.async {
            guard !self.finished else { return }
            if data.isEmpty {
                if standardError {
                    self.errorReachedEOF = true
                    self.errorPipe.fileHandleForReading.readabilityHandler = nil
                } else {
                    self.outputReachedEOF = true
                    self.outputPipe.fileHandleForReading.readabilityHandler = nil
                }
            } else {
                self.yield(data, standardError: standardError)
            }
            self.finishIfReady()
        }
    }

    func processTerminated(exitCode: Int32, reason: ProcessTerminationReason) {
        queue.async {
            guard !self.finished else { return }
            self.termination = (exitCode, reason)
            self.finishIfReady()
        }
    }

    private func finishIfReady() {
        guard !finished,
              outputReachedEOF,
              errorReachedEOF,
              let termination else { return }
        finished = true
        continuation.yield(.terminated(exitCode: termination.exitCode, reason: termination.reason))
        continuation.finish()
    }

    private func yield(_ data: Data, standardError: Bool) {
        guard !data.isEmpty else { return }
        continuation.yield(standardError ? .standardError(data) : .standardOutput(data))
    }
}

private final class ProcessState: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process
    private let gracePeriod: Duration
    private var running = false
    private var cancellationRequested = false
    private var cancellationCompleted = false

    init(process: Process, gracePeriod: Duration) {
        self.process = process
        self.gracePeriod = gracePeriod
    }

    var isRunning: Bool {
        lock.withLock { running && process.isRunning }
    }

    func markRunning() {
        lock.withLock { running = true }
    }

    func markTerminated() {
        lock.withLock { running = false }
    }

    func cancel() {
        let shouldTerminate = lock.withLock {
            guard running, !cancellationRequested else { return false }
            cancellationRequested = true
            return true
        }
        guard shouldTerminate else { return }

        let descendants = descendantPIDs(of: process.processIdentifier).compactMap {
            processIdentity(for: $0)
        }
        descendants.reversed().forEach { Darwin.kill($0.pid, SIGTERM) }
        process.terminate()

        let pid = process.processIdentifier
        let delay = gracePeriod
        Task.detached {
            try? await Task.sleep(for: delay)
            descendants.reversed().forEach { identity in
                if self.processIdentity(for: identity.pid) == identity {
                    Darwin.kill(identity.pid, SIGKILL)
                }
            }
            if self.isRunning {
                Darwin.kill(pid, SIGKILL)
            }
            self.lock.withLock { self.cancellationCompleted = true }
        }
    }

    func waitForCancellation() async {
        await Task.detached { [self] in
            while lock.withLock({ cancellationRequested && !cancellationCompleted }) {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }.value
    }

    private func descendantPIDs(of parentPID: pid_t) -> [pid_t] {
        var result: [pid_t] = []
        var pending = [parentPID]

        while let parent = pending.popLast() {
            var children = [pid_t](repeating: 0, count: 256)
            let count = proc_listchildpids(
                parent,
                &children,
                Int32(children.count * MemoryLayout<pid_t>.size)
            )
            guard count > 0 else { continue }
            let liveChildren = children.prefix(min(Int(count), children.count)).filter { $0 > 0 }
            result.append(contentsOf: liveChildren)
            pending.append(contentsOf: liveChildren)
        }

        return result
    }

    private func processIdentity(for pid: pid_t) -> ProcessIdentity? {
        var info = proc_bsdinfo()
        let bytes = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(
                pid,
                PROC_PIDTBSDINFO,
                0,
                $0,
                Int32(MemoryLayout<proc_bsdinfo>.size)
            )
        }
        guard bytes == MemoryLayout<proc_bsdinfo>.size else { return nil }
        return ProcessIdentity(
            pid: pid,
            startSeconds: info.pbi_start_tvsec,
            startMicroseconds: info.pbi_start_tvusec
        )
    }
}

private struct ProcessIdentity: Equatable, Sendable {
    let pid: pid_t
    let startSeconds: UInt64
    let startMicroseconds: UInt64
}
