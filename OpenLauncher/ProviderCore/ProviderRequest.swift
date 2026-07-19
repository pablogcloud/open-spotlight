import Foundation

struct FileContextDisclosure: Equatable, Sendable {
  let fileURL: URL
  let byteCount: Int
  let extractedCharacterCount: Int
  let provider: ProviderIdentifier

  var fileName: String { fileURL.lastPathComponent }

  init(
    fileURL: URL,
    byteCount: Int,
    extractedCharacterCount: Int,
    provider: ProviderIdentifier
  ) throws {
    guard fileURL.isFileURL else { throw ProviderRequestError.contextMustBeAFileURL }
    guard byteCount >= 0, extractedCharacterCount >= 0 else {
      throw ProviderRequestError.invalidContextMetrics
    }

    self.fileURL = fileURL
    self.byteCount = byteCount
    self.extractedCharacterCount = extractedCharacterCount
    self.provider = provider
  }
}

struct ConfirmedFileContext: Equatable, Sendable {
  let disclosure: FileContextDisclosure
  let contents: String
  let confirmedAt: Date

  init(
    disclosure: FileContextDisclosure,
    contents: String,
    confirmedAt: Date = .now
  ) throws {
    guard contents.count == disclosure.extractedCharacterCount else {
      throw ProviderRequestError.contextCharacterCountMismatch
    }

    self.disclosure = disclosure
    self.contents = contents
    self.confirmedAt = confirmedAt
  }
}

struct ProviderRequest: Equatable, Sendable {
  let id: UUID
  let provider: ProviderIdentifier
  let query: String
  let confirmedFileContext: ConfirmedFileContext?

  init(
    id: UUID = UUID(),
    provider: ProviderIdentifier,
    query: String,
    confirmedFileContext: ConfirmedFileContext? = nil
  ) throws {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ProviderRequestError.emptyQuery
    }
    guard confirmedFileContext?.disclosure.provider == provider || confirmedFileContext == nil
    else {
      throw ProviderRequestError.contextProviderMismatch
    }

    self.id = id
    self.provider = provider
    self.query = query
    self.confirmedFileContext = confirmedFileContext
  }
}

struct ProviderPayload: Equatable, Sendable {
  let prompt: String
  let disclosure: FileContextDisclosure?
}

enum ProviderRequestError: Error, Equatable, Sendable {
  case emptyQuery
  case contextMustBeAFileURL
  case invalidContextMetrics
  case contextCharacterCountMismatch
  case contextProviderMismatch
}
