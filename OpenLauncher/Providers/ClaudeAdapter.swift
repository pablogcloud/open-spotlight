import Foundation

struct ClaudeAdapter: CLIProviderAdapter {
    let identifier = ProviderIdentifier.claude
    let executableName = "claude"
    let authenticationProbeArguments: [String]? = ["auth", "status", "--json"]
    let authenticationLaunchArguments = ["auth", "login"]
    let installationURL = URL(string: "https://docs.anthropic.com/en/docs/claude-code/setup")!

    let invocationDisclosure = ProviderInvocationDisclosure(
        summary: "Safe Mode, plan permission mode, no launcher-enabled tools, no saved session.",
        launcherDisablesTools: true,
        residualAccess: "Claude Code still applies provider-managed policy and authentication settings."
    )

    func makeInvocation(executableURL: URL, payload: ProviderPayload) throws -> ProcessInvocation {
        try ProcessInvocation(
            executableURL: executableURL,
            arguments: [
                "-p",
                "--safe-mode",
                "--verbose",
                "--output-format", "stream-json",
                "--include-partial-messages",
                "--permission-mode", "plan",
                "--no-session-persistence",
                "--no-chrome",
                "--disable-slash-commands",
                "--tools", "",
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

        if type == "stream_event",
           ProviderJSON.string("event", "type", in: object) == "content_block_delta",
           ProviderJSON.string("event", "delta", "type", in: object) == "text_delta",
           let text = ProviderJSON.string("event", "delta", "text", in: object),
           !text.isEmpty {
            return [.textDelta(text)]
        }

        if type == "assistant",
           let error = object["error"] as? String,
           let text = assistantText(in: object) {
            return [.failed(failure(error: error, message: text))]
        }

        if type == "result" {
            if ProviderJSON.bool("is_error", in: object) == true {
                let message = object["result"] as? String ?? "Claude request failed."
                let code = object["terminal_reason"] as? String
                return [.failed(failure(error: code, message: message))]
            }
            return [.completed(.init(exitCode: 0))]
        }

        return []
    }

    private func assistantText(in object: [String: Any]) -> String? {
        guard let message = object["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]]
        else { return nil }
        return content.first(where: { $0["type"] as? String == "text" })?["text"] as? String
    }

    private func failure(error: String?, message: String) -> ProviderFailure {
        let lower = "\(error ?? "") \(message)".lowercased()
        let kind: ProviderFailureKind
        if lower.contains("rate_limit") || lower.contains("limit") || lower.contains("429") {
            kind = .rateLimited
        } else if lower.contains("auth") || lower.contains("login") {
            kind = .authentication
        } else if lower.contains("permission") {
            kind = .permissionDenied
        } else {
            kind = .invocation
        }
        return ProviderFailure(kind: kind, providerCode: error, message: message, isRecoverable: true)
    }
}
