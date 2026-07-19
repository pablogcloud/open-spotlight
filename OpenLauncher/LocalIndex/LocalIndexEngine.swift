import Foundation

actor LocalIndexEngine {
  private let scope: LocalIndexScope
  private let store: SQLiteLocalIndexStore
  private let chunker: LocalTextChunker
  private let embedder: any LocalEmbeddingProviding

  init(
    scope: LocalIndexScope,
    databaseURL: URL,
    chunker: LocalTextChunker = LocalTextChunker(),
    embedder: any LocalEmbeddingProviding = AppleSentenceEmbeddingProvider()
  ) throws {
    self.scope = scope
    store = try SQLiteLocalIndexStore(databaseURL: databaseURL)
    self.chunker = chunker
    self.embedder = embedder
  }

  func indexFile(at url: URL) async throws {
    guard scope.allows(url) else { throw LocalIndexError.unapprovedURL(url) }
    let resourceValues = try url.resourceValues(forKeys: [
      .contentModificationDateKey, .fileSizeKey,
    ])
    guard (resourceValues.fileSize ?? 0) <= 2 * 1_024 * 1_024 else {
      throw LocalIndexError.unsupportedFileType("files-over-2MB")
    }
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    guard let text = String(data: data, encoding: .utf8) else {
      throw LocalIndexError.unsupportedFileType(url.pathExtension.lowercased())
    }
    try await index(
      LocalIndexDocument(
        url: url,
        text: text,
        modifiedAt: resourceValues.contentModificationDate ?? .now
      ))
  }

  func index(_ document: LocalIndexDocument) async throws {
    guard scope.allows(document.url) else { throw LocalIndexError.unapprovedURL(document.url) }
    let chunks = chunker.chunks(for: document.text)
    let embeddings = chunks.map { embedder.embedding(for: $0.text) }
    try await store.replace(document: document, chunks: chunks, embeddings: embeddings)
  }

  func search(_ query: String, limit: Int = 8) async throws -> [LocalSearchReference] {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return [] }
    return try await store.search(
      query: normalized,
      queryEmbedding: embedder.embedding(for: normalized),
      allowedRootPaths: scope.approvedRoots.map(\.path),
      limit: limit
    )
  }

  func statistics() async throws -> (documents: Int, chunks: Int) {
    try await store.statistics(allowedRootPaths: scope.approvedRoots.map(\.path))
  }

  func unscopedStatistics() async throws -> (documents: Int, chunks: Int) {
    try await store.statistics()
  }

  func backup(to destinationURL: URL) async throws {
    try await store.backup(to: destinationURL)
  }

  func deleteAll() async throws { try await store.deleteAll() }
}
