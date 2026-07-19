import Foundation

enum ProviderIdentifier: String, CaseIterable, Codable, Hashable, Sendable {
    case claude
    case codex
    case grok

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .grok: "Grok"
        }
    }

    var symbolName: String {
        switch self {
        case .claude: "brain.head.profile"
        case .codex: "terminal"
        case .grok: "bolt"
        }
    }

    var logoAssetName: String {
        switch self {
        case .claude: "ClaudeLogo"
        case .codex: "CodexLogo"
        case .grok: "GrokLogo"
        }
    }

    var nextInCycle: Self {
        guard let index = Self.allCases.firstIndex(of: self) else { return self }
        return Self.allCases[(index + 1) % Self.allCases.count]
    }
}

struct ProviderCapabilities: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt

    static let versionProbe = Self(rawValue: 1 << 0)
    static let streaming = Self(rawValue: 1 << 1)
    static let cancellation = Self(rawValue: 1 << 2)
    static let fileContext = Self(rawValue: 1 << 3)

    static let phaseZeroRequired: Self = [
        .versionProbe,
        .streaming,
        .cancellation,
        .fileContext,
    ]
}

enum ProviderStatus: Equatable, Sendable {
    case unknown
    case probing
    case available(version: String?, executableURL: URL)
    case authenticationRequired(executableURL: URL)
    case unavailable(reason: String)
}

struct ProviderDescriptor: Equatable, Sendable {
    let identifier: ProviderIdentifier
    let status: ProviderStatus
    let capabilities: ProviderCapabilities
}

enum ProviderRunState: String, CaseIterable, Codable, Equatable, Sendable {
    case idle
    case probing
    case ready
    case awaitingDisclosure
    case streaming
    case completed
    case cancelled
    case empty
    case failed

    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .empty, .failed: true
        default: false
        }
    }
}

struct ProviderCompletion: Equatable, Sendable {
    let exitCode: Int32
}

enum ProviderFailureKind: String, Codable, Equatable, Sendable {
    case authentication
    case rateLimited
    case incompatibleVersion
    case invocation
    case malformedOutput
    case permissionDenied
    case unknown
}

struct ProviderFailure: Error, Equatable, Sendable {
    let kind: ProviderFailureKind
    let providerCode: String?
    let message: String
    let isRecoverable: Bool
}

enum NormalizedStreamEvent: Equatable, Sendable {
    case state(ProviderRunState)
    case textDelta(String)
    case completed(ProviderCompletion)
    case failed(ProviderFailure)

    var isTerminal: Bool {
        switch self {
        case .completed, .failed: true
        case let .state(state): state.isTerminal
        case .textDelta: false
        }
    }
}
