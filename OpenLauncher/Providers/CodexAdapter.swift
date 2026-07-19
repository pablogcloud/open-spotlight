import Foundation

struct CodexAdapter: CLIProviderAdapter {
    let identifier = ProviderIdentifier.codex
    let executableName = "codex"
    let authenticationProbeArguments: [String]? = ["login", "status"]
    let authenticationLaunchArguments = ["login"]
    let installationURL = URL(string: "https://developers.openai.com/codex/cli/")!

    let invocationDisclosure = ProviderInvocationDisclosure(
        summary: "Ephemeral session in Codex's read-only sandbox with project rules ignored.",
        launcherDisablesTools: false,
        residualAccess: "Codex may inspect files readable inside its CLI sandbox; writes and network access are blocked by the launcher-selected sandbox."
    )

    func makeInvocation(executableURL: URL, payload: ProviderPayload) throws -> ProcessInvocation {
        try ProcessInvocation(
            executableURL: executableURL,
            arguments: [
                "exec",
                "--json",
                "--sandbox", "read-only",
                "--ephemeral",
                "--ignore-user-config",
                "--ignore-rules",
                "--skip-git-repo-check",
                "-C", "/private/tmp",
                "-",
            ],
            environment: ProviderProcessEnvironment.make(),
            workingDirectoryURL: URL(fileURLWithPath: "/private/tmp"),
            standardInput: Data(payload.prompt.utf8)
        )
    }

    func parse(line: String) -> [NormalizedStreamEvent] {
        guard let object = ProviderJSON.object(from: line),
              let type = object["type"] as? String
        else { return [] }

        if type == "item.completed",
           ProviderJSON.string("item", "type", in: object) == "agent_message",
           let text = ProviderJSON.string("item", "text", in: object),
           !text.isEmpty {
            return [.textDelta(text)]
        }

        if type == "turn.completed" {
            return [.completed(.init(exitCode: 0))]
        }

        if type == "turn.failed" {
            let message = ProviderJSON.string("error", "message", in: object)
                ?? object["message"] as? String
                ?? "Codex request failed."
            return [.failed(.init(
                kind: failureKind(for: message),
                providerCode: ProviderJSON.string("error", "code", in: object),
                message: message,
                isRecoverable: true
            ))]
        }

        return []
    }

    private func failureKind(for message: String) -> ProviderFailureKind {
        let lower = message.lowercased()
        if lower.contains("rate") || lower.contains("limit") { return .rateLimited }
        if lower.contains("auth") || lower.contains("login") { return .authentication }
        if lower.contains("permission") { return .permissionDenied }
        return .invocation
    }
}
