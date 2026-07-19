import Foundation
import SQLite3

actor SQLiteLocalIndexStore {
    private let handle: SQLiteHandle
    private var database: OpaquePointer { handle.pointer }

    init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        handle = try SQLiteHandle(databaseURL: databaseURL)
        try Self.migrate(handle.pointer)
    }

    func replace(
        document: LocalIndexDocument,
        chunks: [LocalIndexChunk],
        embeddings: [LocalEmbedding?]
    ) throws {
        precondition(chunks.count == embeddings.count)
        let documentID = LocalIndexIdentity.documentID(for: document.url)
        try execute("BEGIN IMMEDIATE")
        do {
            try run(
                "DELETE FROM chunks_fts WHERE document_id = ?",
                bindings: [.text(documentID)]
            )
            try run("DELETE FROM chunks WHERE document_id = ?", bindings: [.text(documentID)])
            try run(
                """
                INSERT INTO documents(id, url, title, modified_at, content_hash)
                VALUES(?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    url = excluded.url,
                    title = excluded.title,
                    modified_at = excluded.modified_at,
                    content_hash = excluded.content_hash
                """,
                bindings: [
                    .text(documentID),
                    .text(document.url.path),
                    .text(document.title),
                    .double(document.modifiedAt.timeIntervalSince1970),
                    .text(LocalIndexIdentity.contentHash(document.text)),
                ]
            )

            for (index, chunk) in chunks.enumerated() {
                let chunkID = "\(documentID):\(chunk.ordinal)"
                let embedding = embeddings[index]
                try run(
                    """
                    INSERT INTO chunks(
                        id, document_id, ordinal, body, start_offset, end_offset,
                        embedding_model, embedding
                    ) VALUES(?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(chunkID),
                        .text(documentID),
                        .integer(Int64(chunk.ordinal)),
                        .text(chunk.text),
                        .integer(Int64(chunk.startOffset)),
                        .integer(Int64(chunk.endOffset)),
                        embedding.map { .text($0.model) } ?? .null,
                        embedding.map { .blob(Self.encode($0.values)) } ?? .null,
                    ]
                )
                try run(
                    "INSERT INTO chunks_fts(chunk_id, document_id, title, body) VALUES(?, ?, ?, ?)",
                    bindings: [.text(chunkID), .text(documentID), .text(document.title), .text(chunk.text)]
                )
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func search(
        query: String,
        queryEmbedding: LocalEmbedding?,
        allowedRootPaths: [String],
        limit: Int = 8
    ) throws -> [LocalSearchReference] {
        guard limit > 0, !allowedRootPaths.isEmpty else { return [] }
        let candidateLimit = max(limit * 6, 24)
        let lexical = try lexicalCandidates(
            query: query,
            allowedRootPaths: allowedRootPaths,
            limit: candidateLimit
        )
        let semantic = try semanticCandidates(
            embedding: queryEmbedding,
            allowedRootPaths: allowedRootPaths,
            limit: candidateLimit
        )

        var candidates: [String: Candidate] = [:]
        var lexicalRanks: [String: Int] = [:]
        var semanticRanks: [String: Int] = [:]
        for (rank, candidate) in lexical.enumerated() {
            candidates[candidate.id] = candidate
            lexicalRanks[candidate.id] = rank + 1
        }
        for (rank, candidate) in semantic.enumerated() {
            candidates[candidate.id] = candidate
            semanticRanks[candidate.id] = rank + 1
        }

        return candidates.values.map { candidate in
            let lexicalRank = lexicalRanks[candidate.id]
            let semanticRank = semanticRanks[candidate.id]
            let lexicalScore = lexicalRank.map { 0.45 / Double(60 + $0) } ?? 0
            let semanticScore = semanticRank.map { 0.55 / Double(60 + $0) } ?? 0
            return LocalSearchReference(
                id: candidate.id,
                fileURL: candidate.fileURL,
                title: candidate.title,
                excerpt: candidate.body,
                modifiedAt: candidate.modifiedAt,
                score: lexicalScore + semanticScore,
                lexicalRank: lexicalRank,
                semanticRank: semanticRank
            )
        }
        .sorted {
            if $0.score == $1.score { return $0.modifiedAt > $1.modifiedAt }
            return $0.score > $1.score
        }
        .prefix(limit)
        .map { $0 }
    }

    func statistics() throws -> (documents: Int, chunks: Int) {
        (try scalarCount("SELECT COUNT(*) FROM documents"), try scalarCount("SELECT COUNT(*) FROM chunks"))
    }

    func statistics(allowedRootPaths: [String]) throws -> (documents: Int, chunks: Int) {
        guard !allowedRootPaths.isEmpty else { return (0, 0) }
        let scope = Self.scopeClause(allowedRootPaths: allowedRootPaths, tableAlias: "d")
        let statement = try prepare(
            """
            SELECT COUNT(DISTINCT d.id), COUNT(c.id)
            FROM documents d
            LEFT JOIN chunks c ON c.document_id = d.id
            WHERE \(scope.sql)
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(scope.bindings, to: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { throw databaseError() }
        return (
            Int(sqlite3_column_int64(statement, 0)),
            Int(sqlite3_column_int64(statement, 1))
        )
    }

    func backup(to destinationURL: URL) throws {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var destination: OpaquePointer?
        guard sqlite3_open_v2(
            destinationURL.path,
            &destination,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let destination
        else {
            let message = destination.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to create index backup"
            sqlite3_close(destination)
            throw LocalIndexError.invalidDatabase(message)
        }
        defer { sqlite3_close(destination) }
        guard let backup = sqlite3_backup_init(destination, "main", database, "main") else {
            throw LocalIndexError.invalidDatabase(String(cString: sqlite3_errmsg(destination)))
        }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE, finish == SQLITE_OK else {
            throw LocalIndexError.invalidDatabase(String(cString: sqlite3_errmsg(destination)))
        }
    }

    func deleteAll() throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("DELETE FROM chunks_fts")
            try execute("DELETE FROM documents")
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private nonisolated static func migrate(_ database: OpaquePointer) throws {
        let statements = [
            "PRAGMA foreign_keys = ON",
            "PRAGMA journal_mode = WAL",
            "PRAGMA synchronous = NORMAL",
            """
            CREATE TABLE IF NOT EXISTS documents(
                id TEXT PRIMARY KEY,
                url TEXT NOT NULL UNIQUE,
                title TEXT NOT NULL,
                modified_at REAL NOT NULL,
                content_hash TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS chunks(
                id TEXT PRIMARY KEY,
                document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
                ordinal INTEGER NOT NULL,
                body TEXT NOT NULL,
                start_offset INTEGER NOT NULL,
                end_offset INTEGER NOT NULL,
                embedding_model TEXT,
                embedding BLOB
            )
            """,
            "CREATE INDEX IF NOT EXISTS chunks_document_id ON chunks(document_id)",
            "CREATE INDEX IF NOT EXISTS chunks_embedding_model ON chunks(embedding_model)",
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
                chunk_id UNINDEXED,
                document_id UNINDEXED,
                title,
                body,
                tokenize = 'unicode61 remove_diacritics 2'
            )
            """,
        ]
        for sql in statements where sqlite3_exec(database, sql, nil, nil, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(database))
            throw LocalIndexError.invalidDatabase(message)
        }
    }

    private func lexicalCandidates(
        query: String,
        allowedRootPaths: [String],
        limit: Int
    ) throws -> [Candidate] {
        guard let expression = Self.ftsExpression(for: query) else { return [] }
        let scope = Self.scopeClause(allowedRootPaths: allowedRootPaths, tableAlias: "d")
        return try readCandidates(
            """
            SELECT c.id, d.url, d.title, c.body, d.modified_at, NULL, NULL
            FROM chunks_fts
            JOIN chunks c ON c.id = chunks_fts.chunk_id
            JOIN documents d ON d.id = c.document_id
            WHERE chunks_fts MATCH ? AND (\(scope.sql))
            ORDER BY bm25(chunks_fts)
            LIMIT ?
            """,
            bindings: [.text(expression)] + scope.bindings + [.integer(Int64(limit))]
        )
    }

    private func semanticCandidates(
        embedding: LocalEmbedding?,
        allowedRootPaths: [String],
        limit: Int
    ) throws -> [Candidate] {
        guard let embedding else { return [] }
        let scope = Self.scopeClause(allowedRootPaths: allowedRootPaths, tableAlias: "d")
        let candidates = try readCandidates(
            """
            SELECT c.id, d.url, d.title, c.body, d.modified_at, c.embedding_model, c.embedding
            FROM chunks c
            JOIN documents d ON d.id = c.document_id
            WHERE c.embedding_model = ? AND c.embedding IS NOT NULL AND (\(scope.sql))
            """,
            bindings: [.text(embedding.model)] + scope.bindings
        )
        return candidates
            .map { candidate in
                var value = candidate
                value.similarity = Self.cosineSimilarity(embedding.values, candidate.embedding ?? [])
                return value
            }
            .filter { $0.similarity >= 0.25 }
            .sorted { $0.similarity > $1.similarity }
            .prefix(limit)
            .map { $0 }
    }

    private func readCandidates(_ sql: String, bindings: [Binding]) throws -> [Candidate] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        var result: [Candidate] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = text(at: 0, in: statement),
                  let path = text(at: 1, in: statement),
                  let title = text(at: 2, in: statement),
                  let body = text(at: 3, in: statement)
            else { continue }
            let model = text(at: 5, in: statement)
            let vector = blob(at: 6, in: statement).map(Self.decode)
            result.append(Candidate(
                id: id,
                fileURL: URL(fileURLWithPath: path),
                title: title,
                body: body,
                modifiedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
                embeddingModel: model,
                embedding: vector,
                similarity: 0
            ))
        }
        try checkReadCompletion(statement)
        return result
    }

    private func scalarCount(_ sql: String) throws -> Int {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw databaseError()
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func run(_ sql: String, bindings: [Binding]) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw databaseError() }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else { throw databaseError() }
        return statement
    }

    private func bind(_ bindings: [Binding], to statement: OpaquePointer) throws {
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32 = switch binding {
            case let .text(value): value.withCString { sqlite3_bind_text(statement, index, $0, -1, sqliteTransient) }
            case let .integer(value): sqlite3_bind_int64(statement, index, value)
            case let .double(value): sqlite3_bind_double(statement, index, value)
            case let .blob(value): value.withUnsafeBytes {
                sqlite3_bind_blob(statement, index, $0.baseAddress, Int32(value.count), sqliteTransient)
            }
            case .null: sqlite3_bind_null(statement, index)
            }
            guard status == SQLITE_OK else { throw databaseError() }
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw databaseError() }
    }

    private func checkReadCompletion(_ statement: OpaquePointer) throws {
        let status = sqlite3_errcode(database)
        guard status == SQLITE_OK || status == SQLITE_DONE || status == SQLITE_ROW else {
            throw databaseError()
        }
    }

    private func databaseError() -> LocalIndexError {
        .invalidDatabase(String(cString: sqlite3_errmsg(database)))
    }

    private func text(at index: Int32, in statement: OpaquePointer) -> String? {
        sqlite3_column_text(statement, index).map { String(cString: $0) }
    }

    private func blob(at index: Int32, in statement: OpaquePointer) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
    }

    private static func encode(_ values: [Float]) -> Data {
        values.withUnsafeBytes { Data($0) }
    }

    private static func decode(_ data: Data) -> [Float] {
        guard data.count.isMultiple(of: MemoryLayout<Float>.size) else { return [] }
        var values = [Float](repeating: 0, count: data.count / MemoryLayout<Float>.size)
        _ = values.withUnsafeMutableBytes { destination in data.copyBytes(to: destination) }
        return values
    }

    private static func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard !lhs.isEmpty, lhs.count == rhs.count else { return -.infinity }
        var dot = 0.0
        var leftMagnitude = 0.0
        var rightMagnitude = 0.0
        for index in lhs.indices {
            let left = Double(lhs[index])
            let right = Double(rhs[index])
            dot += left * right
            leftMagnitude += left * left
            rightMagnitude += right * right
        }
        guard leftMagnitude > 0, rightMagnitude > 0 else { return -.infinity }
        return dot / (leftMagnitude.squareRoot() * rightMagnitude.squareRoot())
    }

    private static func ftsExpression(for query: String) -> String? {
        let tokens = query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
        guard !tokens.isEmpty else { return nil }
        return tokens.prefix(12).map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: " OR ")
    }

    private static func scopeClause(
        allowedRootPaths: [String],
        tableAlias: String
    ) -> (sql: String, bindings: [Binding]) {
        var clauses: [String] = []
        var bindings: [Binding] = []
        for rawPath in allowedRootPaths {
            let path = URL(fileURLWithPath: rawPath, isDirectory: true).standardizedFileURL.path
            let prefix = path.hasSuffix("/") ? path : path + "/"
            clauses.append("(\(tableAlias).url = ? OR substr(\(tableAlias).url, 1, length(?)) = ?)")
            bindings.append(contentsOf: [.text(path), .text(prefix), .text(prefix)])
        }
        return (clauses.joined(separator: " OR "), bindings)
    }
}

private struct Candidate {
    let id: String
    let fileURL: URL
    let title: String
    let body: String
    let modifiedAt: Date
    let embeddingModel: String?
    let embedding: [Float]?
    var similarity: Double
}

private enum Binding {
    case text(String)
    case integer(Int64)
    case double(Double)
    case blob(Data)
    case null
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private final class SQLiteHandle: @unchecked Sendable {
    let pointer: OpaquePointer

    init(databaseURL: URL) throws {
        var connection: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &connection, flags, nil) == SQLITE_OK,
              let connection
        else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database"
            sqlite3_close(connection)
            throw LocalIndexError.invalidDatabase(message)
        }
        pointer = connection
    }

    deinit { sqlite3_close(pointer) }
}
