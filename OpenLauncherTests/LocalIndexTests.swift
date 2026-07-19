import Foundation
import XCTest
@testable import OpenLauncher

final class LocalIndexTests: XCTestCase {
    func testScopeAllowsOnlyApprovedSupportedVisibleFiles() throws {
        let root = localIndexTestBase("Scope").appending(path: "Approved", directoryHint: .isDirectory)
        let scope = LocalIndexScope(
            approvedRoots: [root],
            excludedURLs: [root.appending(path: "private")]
        )

        XCTAssertTrue(scope.allows(root.appending(path: "notes/project.md")))
        XCTAssertFalse(scope.allows(root.appending(path: "private/payments.md")))
        XCTAssertFalse(scope.allows(root.appending(path: ".ssh/config.txt")))
        XCTAssertFalse(scope.allows(root.appending(path: "photo.png")))
        XCTAssertFalse(scope.allows(URL(fileURLWithPath: "/tmp/outside.md")))
    }

    func testRootPolicyRejectsWholeVolumeSystemAndVolumeRoots() {
        for path in ["/", "/System", "/System/Library", "/Library", "/private/var", "/Volumes", "/Volumes/Archive"] {
            XCTAssertNotNil(
                LocalIndexRootPolicy.rejectionReason(for: URL(fileURLWithPath: path, isDirectory: true)),
                "Expected \(path) to be rejected"
            )
        }
        XCTAssertNil(LocalIndexRootPolicy.rejectionReason(
            for: URL(fileURLWithPath: "/Volumes/Archive/Documents", isDirectory: true)
        ))
        XCTAssertNil(LocalIndexRootPolicy.rejectionReason(
            for: URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)
        ))
    }

    func testScopeRejectsHiddenDependencyPackageAndSymlinkEscape() throws {
        let base = localIndexTestBase("ScopeSecurity")
        let root = base.appending(path: "Approved", directoryHint: .isDirectory)
        let outside = base.appending(path: "Outside", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data("outside approved scope".utf8).write(to: outside.appending(path: "escaped.md"))
        let link = root.appending(path: "linked", directoryHint: .isDirectory)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        defer { try? FileManager.default.removeItem(at: base) }
        let scope = LocalIndexScope(approvedRoots: [root])

        XCTAssertFalse(scope.allows(root.appending(path: ".hidden/notes.md")))
        XCTAssertFalse(scope.allows(root.appending(path: "node_modules/package/readme.md")))
        XCTAssertFalse(scope.allows(root.appending(path: "Example.app/Contents/notes.md")))
        XCTAssertFalse(scope.allows(link.appending(path: "escaped.md")))
        XCTAssertTrue(scope.allows(root.appending(path: "Projects/notes.md")))
    }

    func testChunkerCreatesBoundedOverlappingReferences() {
        let chunker = LocalTextChunker(targetCharacterCount: 120, overlapCharacterCount: 20)
        let text = (0..<40).map { "Paragraph \($0) contains searchable project details." }.joined(separator: "\n\n")
        let chunks = chunker.chunks(for: text)

        XCTAssertGreaterThan(chunks.count, 3)
        XCTAssertEqual(chunks.map(\.ordinal), Array(chunks.indices))
        XCTAssertTrue(chunks.allSatisfy { !$0.text.isEmpty && $0.endOffset > $0.startOffset })
        for index in 1..<chunks.count {
            XCTAssertLessThan(chunks[index].startOffset, chunks[index - 1].endOffset)
        }
    }

    func testPersistentHybridIndexReturnsLexicalAndSemanticReferences() async throws {
        let fixture = try IndexFixture()
        let engine = try fixture.makeEngine()
        try await engine.index(LocalIndexDocument(
            url: fixture.root.appending(path: "studio-invoice.md"),
            title: "Studio invoice",
            text: "Invoice for acoustic panels and studio furniture. Total paid to Acme Interiors.",
            modifiedAt: Date(timeIntervalSince1970: 200)
        ))
        try await engine.index(LocalIndexDocument(
            url: fixture.root.appending(path: "vehicle-note.md"),
            title: "Vehicle note",
            text: "We acquired an automobile for regional site visits.",
            modifiedAt: Date(timeIntervalSince1970: 100)
        ))

        let lexical = try await engine.search("acoustic invoice", limit: 3)
        XCTAssertEqual(lexical.first?.title, "Studio invoice")
        XCTAssertNotNil(lexical.first?.lexicalRank)

        let semantic = try await engine.search("car purchase", limit: 3)
        XCTAssertEqual(semantic.first?.title, "Vehicle note")
        XCTAssertNotNil(semantic.first?.semanticRank)
        XCTAssertTrue(semantic.first?.citationLabel.contains("Vehicle note") == true)

        let statistics = try await engine.statistics()
        XCTAssertEqual(statistics.documents, 2)
        XCTAssertEqual(statistics.chunks, 2)
    }

    func testReplacingDocumentRemovesStaleTermsAndDeleteAllClearsIndex() async throws {
        let fixture = try IndexFixture()
        let engine = try fixture.makeEngine()
        let url = fixture.root.appending(path: "changing.md")
        try await engine.index(LocalIndexDocument(url: url, text: "obsolete telescope notes"))
        let initialTelescopeResults = try await engine.search("telescope")
        XCTAssertEqual(initialTelescopeResults.count, 1)

        try await engine.index(LocalIndexDocument(url: url, text: "current landscape architecture notes"))
        let replacedTelescopeResults = try await engine.search("telescope")
        let landscapeResults = try await engine.search("landscape")
        XCTAssertTrue(replacedTelescopeResults.allSatisfy { result in
            result.lexicalRank == nil && !result.excerpt.contains("obsolete telescope")
        })
        XCTAssertEqual(landscapeResults.count, 1)

        try await engine.deleteAll()
        let statistics = try await engine.statistics()
        XCTAssertEqual(statistics.documents, 0)
        XCTAssertEqual(statistics.chunks, 0)
    }

    func testUnapprovedDocumentNeverReachesStore() async throws {
        let fixture = try IndexFixture()
        let engine = try fixture.makeEngine()
        let outside = LocalIndexDocument(
            url: fixture.root.deletingLastPathComponent().appending(path: "outside.md"),
            text: "must never be indexed"
        )

        do {
            try await engine.index(outside)
            XCTFail("Expected the scope boundary to reject the document")
        } catch let error as LocalIndexError {
            guard case .unapprovedURL = error else { return XCTFail("Unexpected error: \(error)") }
        }
        let statistics = try await engine.statistics()
        XCTAssertEqual(statistics.documents, 0)
    }

    func testSemanticRetrievalDropsOrthogonalCandidates() async throws {
        let fixture = try IndexFixture()
        let engine = try fixture.makeEngine()
        try await engine.index(LocalIndexDocument(
            url: fixture.root.appending(path: "vehicle-note.md"),
            text: "We acquired an automobile for regional site visits."
        ))

        let results = try await engine.search("weather forecast")
        XCTAssertTrue(results.isEmpty)
    }

    func testIndexServiceRebuildsApprovedFolderAndCanClearIt() async throws {
        let base = localIndexTestBase("Service")
        let root = base.appending(path: "Approved", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("Quarterly material budget for the Merida project".utf8)
            .write(to: root.appending(path: "budget.md"))
        defer { try? FileManager.default.removeItem(at: base) }
        let service = LocalIndexService(databaseURL: base.appending(path: "index.sqlite"))

        let rebuilt = try await service.rebuild(roots: [root])
        let results = try await service.search("material budget", roots: [root], limit: 4)

        XCTAssertEqual(rebuilt.documents, 1)
        XCTAssertEqual(results.first?.title, "budget")

        try await service.clear(roots: [root])
        let cleared = try await service.statistics(roots: [root])
        XCTAssertEqual(cleared.documents, 0)
    }

    func testIndexServiceEnforcesCurrentScopeWhenDatabaseContainsOldRoot() async throws {
        let base = localIndexTestBase("ScopeQuery")
        let oldRoot = base.appending(path: "Old", directoryHint: .isDirectory)
        let newRoot = base.appending(path: "New", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: oldRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newRoot, withIntermediateDirectories: true)
        try Data("confidential retired project notes".utf8)
            .write(to: oldRoot.appending(path: "retired.md"))
        defer { try? FileManager.default.removeItem(at: base) }
        let service = LocalIndexService(databaseURL: base.appending(path: "index.sqlite"))
        _ = try await service.rebuild(roots: [oldRoot])

        let values = try await service.search("retired project", roots: [newRoot], limit: 4)

        XCTAssertTrue(values.isEmpty)
    }

    func testRebuildPreservesUsableRowsInsteadOfDeletingAtStart() async throws {
        let base = localIndexTestBase("NonDestructive")
        let root = base.appending(path: "Approved", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let oldURL = root.appending(path: "old.md")
        try Data("durable sentinel telescope".utf8).write(to: oldURL)
        defer { try? FileManager.default.removeItem(at: base) }
        let service = LocalIndexService(databaseURL: base.appending(path: "index.sqlite"))
        _ = try await service.rebuild(roots: [root])

        try FileManager.default.removeItem(at: oldURL)
        try Data("new landscape document".utf8).write(to: root.appending(path: "new.md"))
        _ = try await service.rebuild(roots: [root])

        let retained = try await service.search("durable sentinel", roots: [root], limit: 4)
        XCTAssertEqual(retained.first?.title, "old")
        let statistics = try await service.statistics(roots: [root])
        XCTAssertEqual(statistics.documents, 2)
    }

    func testForbiddenRootFailsBeforeMutatingExistingIndex() async throws {
        let base = localIndexTestBase("ForbiddenRoot")
        let root = base.appending(path: "Approved", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("safe retained evidence".utf8).write(to: root.appending(path: "safe.md"))
        defer { try? FileManager.default.removeItem(at: base) }
        let service = LocalIndexService(databaseURL: base.appending(path: "index.sqlite"))
        _ = try await service.rebuild(roots: [root])

        do {
            _ = try await service.rebuild(roots: [URL(fileURLWithPath: "/", isDirectory: true)])
            XCTFail("Expected root policy failure")
        } catch let error as LocalIndexError {
            guard case .forbiddenRoot = error else { return XCTFail("Unexpected error: \(error)") }
        }

        let retained = try await service.search("retained evidence", roots: [root], limit: 4)
        XCTAssertEqual(retained.first?.title, "safe")
    }

    func testSearchAndStatisticsApplyScopeBeforeLimitAndCount() async throws {
        let base = localIndexTestBase("ScopedSQL")
        let oldRoot = base.appending(path: "Old", directoryHint: .isDirectory)
        let newRoot = base.appending(path: "New", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: oldRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newRoot, withIntermediateDirectories: true)
        for index in 0..<40 {
            try Data("shared budget stale \(index)".utf8)
                .write(to: oldRoot.appending(path: "stale-\(index).md"))
        }
        try Data("shared budget current".utf8).write(to: newRoot.appending(path: "current.md"))
        defer { try? FileManager.default.removeItem(at: base) }
        let service = LocalIndexService(databaseURL: base.appending(path: "index.sqlite"))
        _ = try await service.rebuild(roots: [oldRoot])
        _ = try await service.rebuild(roots: [newRoot])

        let results = try await service.search("shared budget", roots: [newRoot], limit: 1)
        let statistics = try await service.statistics(roots: [newRoot])

        XCTAssertEqual(results.first?.title, "current")
        XCTAssertEqual(statistics.documents, 1)
        XCTAssertEqual(statistics.chunks, 1)
    }

    func testLegacyWholeVolumeIndexIsBackedUpThenQuarantined() async throws {
        let base = localIndexTestBase("Quarantine")
        let root = base.appending(path: "Approved", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("legacy unsafe content".utf8).write(to: root.appending(path: "legacy.md"))
        defer { try? FileManager.default.removeItem(at: base) }
        let service = LocalIndexService(databaseURL: base.appending(path: "index.sqlite"))
        _ = try await service.rebuild(roots: [root])

        let result = try await service.quarantineForbiddenRoots(paths: ["/"])

        XCTAssertEqual(result?.removedDocumentCount, 1)
        XCTAssertNotNil(result?.backupURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result?.backupURL?.path ?? ""))
        let backup = try LocalIndexEngine(
            scope: LocalIndexScope(approvedRoots: []),
            databaseURL: try XCTUnwrap(result?.backupURL),
            embedder: FixtureEmbeddingProvider()
        )
        let backupStatistics = try await backup.unscopedStatistics()
        XCTAssertEqual(backupStatistics.documents, 1)
        let statistics = try await service.statistics(roots: [root])
        XCTAssertEqual(statistics.documents, 0)
    }
}

private struct IndexFixture {
    let root: URL
    let databaseURL: URL

    init() throws {
        let base = localIndexTestBase("Index")
        root = base.appending(path: "Approved", directoryHint: .isDirectory)
        databaseURL = base.appending(path: "index.sqlite")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func makeEngine() throws -> LocalIndexEngine {
        try LocalIndexEngine(
            scope: LocalIndexScope(approvedRoots: [root]),
            databaseURL: databaseURL,
            chunker: LocalTextChunker(targetCharacterCount: 800, overlapCharacterCount: 80),
            embedder: FixtureEmbeddingProvider()
        )
    }
}

private func localIndexTestBase(_ label: String) -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/Open Spotlight Test Fixtures", directoryHint: .isDirectory)
        .appending(path: "\(label)-\(UUID().uuidString)", directoryHint: .isDirectory)
}

private struct FixtureEmbeddingProvider: LocalEmbeddingProviding {
    func embedding(for text: String) -> LocalEmbedding? {
        let lower = text.lowercased()
        let values: [Float]
        if lower.contains("car") || lower.contains("automobile") || lower.contains("vehicle") {
            values = [1, 0, 0, 0]
        } else if lower.contains("invoice") || lower.contains("paid") {
            values = [0, 1, 0, 0]
        } else if lower.contains("weather") || lower.contains("forecast") {
            values = [0, 0, 0, 1]
        } else {
            values = [0, 0, 1, 0]
        }
        return LocalEmbedding(model: "fixture-v1", values: values)
    }
}
