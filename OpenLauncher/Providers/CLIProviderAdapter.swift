import Foundation

struct ProviderInvocationDisclosure: Equatable, Sendable {
    let summary: String
    let launcherDisablesTools: Bool
    let residualAccess: String?
}

protocol CLIProviderAdapter: Sendable {
    var identifier: ProviderIdentifier { get }
    var executableName: String { get }
    var executableCandidates: [URL] { get }
    var versionArguments: [String] { get }
    var authenticationProbeArguments: [String]? { get }
    var authenticationFileURL: URL? { get }
    var authenticationLaunchArguments: [String] { get }
    var installationURL: URL { get }
    var invocationDisclosure: ProviderInvocationDisclosure { get }

    func makeInvocation(executableURL: URL, payload: ProviderPayload) throws -> ProcessInvocation
    func parse(line: String) -> [NormalizedStreamEvent]
}

extension CLIProviderAdapter {
    var versionArguments: [String] { ["--version"] }
    var authenticationProbeArguments: [String]? { nil }
    var authenticationFileURL: URL? { nil }

    var executableCandidates: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let paths = [
            "/opt/homebrew/bin/\(executableName)",
            "/usr/local/bin/\(executableName)",
            "/usr/bin/\(executableName)",
            home.appending(path: ".local/bin/\(executableName)").path,
            home.appending(path: ".grok/bin/\(executableName)").path,
        ]
        return paths.map { URL(fileURLWithPath: $0) }
    }
}

struct ExecutableLocator: Sendable {
    let environmentPath: String
    let includeDefaultCandidates: Bool
    let explicitExecutables: [ProviderIdentifier: URL]

    init(
        environmentPath: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
        includeDefaultCandidates: Bool = true,
        explicitExecutables: [ProviderIdentifier: URL] = [:]
    ) {
        self.environmentPath = environmentPath
        self.includeDefaultCandidates = includeDefaultCandidates
        self.explicitExecutables = explicitExecutables
    }

    func locate(for adapter: any CLIProviderAdapter) -> URL? {
        if let explicit = explicitExecutables[adapter.identifier] {
            return FileManager.default.isExecutableFile(atPath: explicit.path) ? explicit : nil
        }
        let pathCandidates = environmentPath
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appending(path: adapter.executableName) }
        let defaults = includeDefaultCandidates ? adapter.executableCandidates : []
        return (defaults + pathCandidates).first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }
}

enum ProviderAdapterFactory {
    static func make(_ identifier: ProviderIdentifier) -> any CLIProviderAdapter {
        switch identifier {
        case .claude: ClaudeAdapter()
        case .codex: CodexAdapter()
        case .grok: GrokAdapter()
        }
    }
}
