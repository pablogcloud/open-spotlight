import Foundation

enum LocalIndexRunState: String, Equatable, Sendable {
    case idle
    case indexing
    case cancelled
    case partial
    case complete
    case failed
    case quarantined
}

struct LocalIndexProgress: Equatable, Sendable {
    let state: LocalIndexRunState
    let discovered: Int
    let processed: Int
    let indexed: Int
    let skipped: Int
    let failed: Int
    let currentPath: String?
    let recentErrors: [String]

    static let idle = LocalIndexProgress(
        state: .idle,
        discovered: 0,
        processed: 0,
        indexed: 0,
        skipped: 0,
        failed: 0,
        currentPath: nil,
        recentErrors: []
    )
}

struct LocalIndexStatistics: Equatable, Sendable {
    let documents: Int
    let chunks: Int
    let discovered: Int
    let processed: Int
    let indexed: Int
    let skipped: Int
    let failed: Int
    let state: LocalIndexRunState
    let recentErrors: [String]

    init(
        documents: Int,
        chunks: Int,
        discovered: Int = 0,
        processed: Int = 0,
        indexed: Int = 0,
        skipped: Int = 0,
        failed: Int = 0,
        state: LocalIndexRunState = .idle,
        recentErrors: [String] = []
    ) {
        self.documents = documents
        self.chunks = chunks
        self.discovered = discovered
        self.processed = processed
        self.indexed = indexed
        self.skipped = skipped
        self.failed = failed
        self.state = state
        self.recentErrors = recentErrors
    }
}

struct LocalIndexQuarantineResult: Equatable, Sendable {
    let removedDocumentCount: Int
    let backupURL: URL?
}

protocol LocalIndexServicing: Sendable {
    func search(_ query: String, roots: [URL], limit: Int) async throws -> [LocalSearchReference]
    func rebuild(roots: [URL]) async throws -> LocalIndexStatistics
    func rebuild(
        roots: [URL],
        progress: @Sendable (LocalIndexProgress) async -> Void
    ) async throws -> LocalIndexStatistics
    func statistics(roots: [URL]) async throws -> LocalIndexStatistics
    func clear(roots: [URL]) async throws
    func quarantineForbiddenRoots(paths: [String]) async throws -> LocalIndexQuarantineResult?
}

extension LocalIndexServicing {
    func rebuild(
        roots: [URL],
        progress: @Sendable (LocalIndexProgress) async -> Void
    ) async throws -> LocalIndexStatistics {
        await progress(LocalIndexProgress(
            state: .indexing,
            discovered: 0,
            processed: 0,
            indexed: 0,
            skipped: 0,
            failed: 0,
            currentPath: nil,
            recentErrors: []
        ))
        let values = try await rebuild(roots: roots)
        await progress(LocalIndexProgress(
            state: values.state,
            discovered: values.discovered,
            processed: values.processed,
            indexed: values.indexed,
            skipped: values.skipped,
            failed: values.failed,
            currentPath: nil,
            recentErrors: values.recentErrors
        ))
        return values
    }

    func quarantineForbiddenRoots(paths: [String]) async throws -> LocalIndexQuarantineResult? {
        nil
    }
}

actor LocalIndexService: LocalIndexServicing {
    private let databaseURL: URL
    private var engine: LocalIndexEngine?
    private var configuredRootPaths: [String] = []

    init(databaseURL: URL = LocalIndexService.defaultDatabaseURL()) {
        self.databaseURL = databaseURL
    }

    func search(_ query: String, roots: [URL], limit: Int) async throws -> [LocalSearchReference] {
        let validatedRoots = try LocalIndexRootPolicy.validate(roots)
        guard !validatedRoots.isEmpty else { return [] }
        let scope = LocalIndexScope(approvedRoots: validatedRoots)
        return try await configuredEngine(roots: validatedRoots)
            .search(query, limit: max(limit * 3, limit))
            .filter { scope.allows($0.fileURL) }
            .prefix(limit)
            .map { $0 }
    }

    func rebuild(roots: [URL]) async throws -> LocalIndexStatistics {
        try await rebuild(roots: roots) { _ in }
    }

    func rebuild(
        roots: [URL],
        progress: @Sendable (LocalIndexProgress) async -> Void
    ) async throws -> LocalIndexStatistics {
        let validatedRoots = try LocalIndexRootPolicy.validate(roots)
        guard !validatedRoots.isEmpty else {
            let empty = LocalIndexStatistics(documents: 0, chunks: 0, state: .complete)
            await progress(Self.progress(from: empty))
            return empty
        }

        let index = try configuredEngine(roots: validatedRoots)
        let scope = LocalIndexScope(approvedRoots: validatedRoots)
        var discovered = 0
        var processed = 0
        var indexed = 0
        var skipped = 0
        var failed = 0
        var recentErrors: [String] = []

        await progress(LocalIndexProgress(
            state: .indexing,
            discovered: 0,
            processed: 0,
            indexed: 0,
            skipped: 0,
            failed: 0,
            currentPath: nil,
            recentErrors: []
        ))

        for root in validatedRoots {
            guard !Task.isCancelled else {
                await progress(Self.cancelledProgress(
                    discovered: discovered,
                    processed: processed,
                    indexed: indexed,
                    skipped: skipped,
                    failed: failed,
                    errors: recentErrors
                ))
                throw CancellationError()
            }

            var rootEnumerationErrors: [String] = []
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { url, error in
                    if rootEnumerationErrors.count < 5 {
                        rootEnumerationErrors.append("\(url.path): \(error.localizedDescription)")
                    }
                    return true
                }
            ) else {
                failed += 1
                recentErrors.append("Unable to enumerate \(root.path)")
                continue
            }

            while let url = enumerator.nextObject() as? URL {
                discovered += 1
                guard !Task.isCancelled else {
                    await progress(Self.cancelledProgress(
                        discovered: discovered,
                        processed: processed,
                        indexed: indexed,
                        skipped: skipped,
                        failed: failed,
                        errors: recentErrors
                    ))
                    throw CancellationError()
                }
                guard scope.allows(url) else {
                    skipped += 1
                    if discovered.isMultiple(of: 25) {
                        await progress(Self.indexingProgress(
                            discovered: discovered,
                            processed: processed,
                            indexed: indexed,
                            skipped: skipped,
                            failed: failed,
                            path: url.path,
                            errors: recentErrors
                        ))
                    }
                    continue
                }

                processed += 1
                do {
                    try await index.indexFile(at: url)
                    indexed += 1
                } catch LocalIndexError.unsupportedFileType {
                    skipped += 1
                } catch {
                    failed += 1
                    if recentErrors.count < 5 {
                        recentErrors.append("\(url.path): \(error.localizedDescription)")
                    }
                }

                if processed.isMultiple(of: 10) {
                    await progress(Self.indexingProgress(
                        discovered: discovered,
                        processed: processed,
                        indexed: indexed,
                        skipped: skipped,
                        failed: failed,
                        path: url.path,
                        errors: recentErrors
                    ))
                }
            }

            failed += rootEnumerationErrors.count
            for error in rootEnumerationErrors where recentErrors.count < 5 {
                recentErrors.append(error)
            }
        }

        let stored = try await statistics(roots: validatedRoots)
        let state: LocalIndexRunState = failed == 0 ? .complete : .partial
        let result = LocalIndexStatistics(
            documents: stored.documents,
            chunks: stored.chunks,
            discovered: discovered,
            processed: processed,
            indexed: indexed,
            skipped: skipped,
            failed: failed,
            state: state,
            recentErrors: recentErrors
        )
        await progress(Self.progress(from: result))
        return result
    }

    func statistics(roots: [URL]) async throws -> LocalIndexStatistics {
        let validatedRoots = try LocalIndexRootPolicy.validate(roots)
        guard !validatedRoots.isEmpty else { return LocalIndexStatistics(documents: 0, chunks: 0) }
        let values = try await configuredEngine(roots: validatedRoots).statistics()
        return LocalIndexStatistics(documents: values.documents, chunks: values.chunks)
    }

    func clear(roots: [URL]) async throws {
        let validatedRoots = try LocalIndexRootPolicy.validate(roots)
        try await configuredEngine(roots: validatedRoots).deleteAll()
    }

    func quarantineForbiddenRoots(paths: [String]) async throws -> LocalIndexQuarantineResult? {
        guard !paths.isEmpty else { return nil }
        var quarantineEngine: LocalIndexEngine? = try LocalIndexEngine(
            scope: LocalIndexScope(approvedRoots: []),
            databaseURL: databaseURL
        )
        let previous = try await quarantineEngine?.unscopedStatistics()
            ?? (documents: 0, chunks: 0)
        quarantineEngine = nil
        engine = nil
        configuredRootPaths = []

        let backupURL: URL?
        if FileManager.default.fileExists(atPath: databaseURL.path), previous.documents > 0 {
            let directory = databaseURL.deletingLastPathComponent()
                .appending(path: "Quarantine", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appending(
                path: "LocalIndex-legacy-\(UUID().uuidString).sqlite",
                directoryHint: .notDirectory
            )
            try FileManager.default.moveItem(at: databaseURL, to: destination)
            for suffix in ["-wal", "-shm"] {
                let source = URL(fileURLWithPath: databaseURL.path + suffix)
                guard FileManager.default.fileExists(atPath: source.path) else { continue }
                let companion = URL(fileURLWithPath: destination.path + suffix)
                try FileManager.default.moveItem(at: source, to: companion)
            }
            backupURL = destination
        } else {
            backupURL = nil
        }
        return LocalIndexQuarantineResult(
            removedDocumentCount: previous.documents,
            backupURL: backupURL
        )
    }

    private func configuredEngine(roots: [URL]) throws -> LocalIndexEngine {
        let normalizedRoots = try LocalIndexRootPolicy.validate(roots).sorted { $0.path < $1.path }
        let paths = normalizedRoots.map(\.path)
        if let engine, paths == configuredRootPaths { return engine }

        let replacement = try LocalIndexEngine(
            scope: LocalIndexScope(approvedRoots: normalizedRoots),
            databaseURL: databaseURL
        )
        engine = replacement
        configuredRootPaths = paths
        return replacement
    }

    private nonisolated static func progress(from values: LocalIndexStatistics) -> LocalIndexProgress {
        LocalIndexProgress(
            state: values.state,
            discovered: values.discovered,
            processed: values.processed,
            indexed: values.indexed,
            skipped: values.skipped,
            failed: values.failed,
            currentPath: nil,
            recentErrors: values.recentErrors
        )
    }

    private nonisolated static func indexingProgress(
        discovered: Int,
        processed: Int,
        indexed: Int,
        skipped: Int,
        failed: Int,
        path: String?,
        errors: [String]
    ) -> LocalIndexProgress {
        LocalIndexProgress(
            state: .indexing,
            discovered: discovered,
            processed: processed,
            indexed: indexed,
            skipped: skipped,
            failed: failed,
            currentPath: path,
            recentErrors: errors
        )
    }

    private nonisolated static func cancelledProgress(
        discovered: Int,
        processed: Int,
        indexed: Int,
        skipped: Int,
        failed: Int,
        errors: [String]
    ) -> LocalIndexProgress {
        LocalIndexProgress(
            state: .cancelled,
            discovered: discovered,
            processed: processed,
            indexed: indexed,
            skipped: skipped,
            failed: failed,
            currentPath: nil,
            recentErrors: errors
        )
    }

    nonisolated static func defaultDatabaseURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return base
            .appending(path: "Open Spotlight", directoryHint: .isDirectory)
            .appending(path: "LocalIndex.sqlite")
    }
}
