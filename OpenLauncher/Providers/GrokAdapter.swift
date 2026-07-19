import Foundation

struct GrokAdapter: CLIProviderAdapter {
    let identifier = ProviderIdentifier.grok
    let executableName = "grok"
    let authenticationLaunchArguments = ["login", "--oauth"]
    let installationURL = URL(string: "https://docs.x.ai/")!

    var authenticationFileURL: URL? {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".grok/auth.json")
    }

    let invocationDisclosure = ProviderInvocationDisclosure(
        summary: "Isolated Grok home in plan mode; tools, web, memory, hooks, plugins, MCP, and subagents disabled.",
        launcherDisablesTools: true,
        residualAccess: "Open Spotlight shares only Grok's existing OAuth file with the isolated CLI process."
    )

    func makeInvocation(executableURL: URL, payload: ProviderPayload) throws -> ProcessInvocation {
        let environment = try isolatedEnvironment()
        return try ProcessInvocation(
            executableURL: executableURL,
            arguments: [
                "--no-auto-update",
                "--prompt-file", "/dev/stdin",
                "--output-format", "streaming-json",
                "--permission-mode", "plan",
                "--disable-web-search",
                "--no-memory",
                "--no-subagents",
                "--cwd", "/private/tmp",
                "--tools", "",
            ],
            environment: environment,
            workingDirectoryURL: URL(fileURLWithPath: "/private/tmp"),
            standardInput: Data(payload.prompt.utf8)
        )
    }

    func parse(line: String) -> [NormalizedStreamEvent] {
        guard let object = ProviderJSON.object(from: line),
              let type = object["type"] as? String
        else { return [] }

        switch type {
        case "text":
            guard let text = object["data"] as? String, !text.isEmpty else { return [] }
            return [.textDelta(text)]
        case "end":
            return [.completed(.init(exitCode: 0))]
        case "error":
            let message = object["data"] as? String
                ?? object["message"] as? String
                ?? "Grok request failed."
            return [.failed(.init(
                kind: failureKind(for: message),
                providerCode: object["code"] as? String,
                message: message,
                isRecoverable: true
            ))]
        default:
            return []
        }
    }

    private func failureKind(for message: String) -> ProviderFailureKind {
        let lower = message.lowercased()
        if lower.contains("rate") || lower.contains("limit") { return .rateLimited }
        if lower.contains("auth") || lower.contains("login") { return .authentication }
        if lower.contains("permission") { return .permissionDenied }
        return .invocation
    }

    private func isolatedEnvironment() throws -> [String: String] {
        var environment = ProviderProcessEnvironment.make()
        guard let userHome = environment["HOME"] else {
            throw ProcessRunnerError.launchFailed("The user home directory is unavailable.")
        }
        let isolatedHome = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "org.openspotlight.app/grok-home", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: isolatedHome,
            withIntermediateDirectories: true
        )
        environment["HOME"] = isolatedHome.path
        environment["GROK_AUTH_PATH"] = URL(fileURLWithPath: userHome)
            .appending(path: ".grok/auth.json")
            .path
        environment["GROK_CLAUDE_MCPS_ENABLED"] = "false"
        environment["GROK_CLAUDE_SKILLS_ENABLED"] = "false"
        environment["GROK_CURSOR_MCPS_ENABLED"] = "false"
        environment["GROK_CURSOR_SKILLS_ENABLED"] = "false"
        return environment
    }
}
