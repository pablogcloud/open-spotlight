import CryptoKit
import Foundation
import NaturalLanguage

struct LocalTextChunker: Sendable {
  let targetCharacterCount: Int
  let overlapCharacterCount: Int

  init(targetCharacterCount: Int = 1_200, overlapCharacterCount: Int = 180) {
    precondition(targetCharacterCount > overlapCharacterCount)
    self.targetCharacterCount = targetCharacterCount
    self.overlapCharacterCount = overlapCharacterCount
  }

  func chunks(for text: String) -> [LocalIndexChunk] {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    guard !normalized.isEmpty else { return [] }

    var chunks: [LocalIndexChunk] = []
    var start = normalized.startIndex
    var ordinal = 0

    while start < normalized.endIndex {
      let target =
        normalized.index(
          start,
          offsetBy: targetCharacterCount,
          limitedBy: normalized.endIndex
        ) ?? normalized.endIndex
      let end = paragraphBoundary(in: normalized, from: start, near: target)
      let value = String(normalized[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
      if !value.isEmpty {
        chunks.append(
          LocalIndexChunk(
            ordinal: ordinal,
            text: value,
            startOffset: normalized.distance(from: normalized.startIndex, to: start),
            endOffset: normalized.distance(from: normalized.startIndex, to: end)
          ))
        ordinal += 1
      }
      guard end < normalized.endIndex else { break }
      start = normalized.index(end, offsetBy: -overlapCharacterCount, limitedBy: start) ?? end
      if start == end { start = normalized.index(after: end) }
    }
    return chunks
  }

  private func paragraphBoundary(
    in text: String, from start: String.Index, near target: String.Index
  ) -> String.Index {
    guard target < text.endIndex else { return text.endIndex }
    let searchEnd = text.index(target, offsetBy: 240, limitedBy: text.endIndex) ?? text.endIndex
    if let boundary = text[target..<searchEnd].range(of: "\n\n")?.upperBound { return boundary }
    if let boundary = text[start..<target].range(of: "\n\n", options: .backwards)?.upperBound,
      text.distance(from: start, to: boundary) >= targetCharacterCount / 2
    {
      return boundary
    }
    return target
  }
}

struct AppleSentenceEmbeddingProvider: LocalEmbeddingProviding {
  func embedding(for text: String) -> LocalEmbedding? {
    let language = dominantLanguage(in: text)
    guard let embedding = NLEmbedding.sentenceEmbedding(for: language),
      let vector = embedding.vector(for: String(text.prefix(4_000)))
    else { return nil }
    return LocalEmbedding(
      model: "apple-sentence-\(language.rawValue)-r\(embedding.revision)-d\(embedding.dimension)",
      values: vector.map(Float.init)
    )
  }

  private func dominantLanguage(in text: String) -> NLLanguage {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(String(text.prefix(2_000)))
    switch recognizer.dominantLanguage {
    case NLLanguage.spanish: return NLLanguage.spanish
    default: return NLLanguage.english
    }
  }
}

enum LocalIndexIdentity {
  static func documentID(for url: URL) -> String {
    digest(url.resolvingSymlinksInPath().standardizedFileURL.path)
  }

  static func contentHash(_ text: String) -> String { digest(text) }

  private static func digest(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}
