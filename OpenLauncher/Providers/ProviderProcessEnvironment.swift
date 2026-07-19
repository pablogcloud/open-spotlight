import Foundation

enum ProviderProcessEnvironment {
    private static let allowedKeys = [
        "HOME",
        "USER",
        "LOGNAME",
        "TMPDIR",
        "SHELL",
        "LANG",
        "LC_ALL",
    ]

    static func make(
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var environment = baseEnvironment.filter { allowedKeys.contains($0.key) }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let additions = [
            home.appending(path: ".local/bin").path,
            home.appending(path: ".grok/bin").path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
        ]
        let existing = baseEnvironment["PATH", default: ""].split(separator: ":").map(String.init)
        environment["PATH"] = (additions + existing).reduce(into: [String]()) { result, path in
            if !result.contains(path) { result.append(path) }
        }.joined(separator: ":")
        return environment
    }
}
