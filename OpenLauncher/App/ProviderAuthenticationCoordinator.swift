import AppKit
import Foundation

@MainActor
struct ProviderAuthenticationCoordinator {
  private let locator = ExecutableLocator()

  func begin(for provider: ProviderIdentifier) throws {
    let adapter = ProviderAdapterFactory.make(provider)
    guard let executableURL = locator.locate(for: adapter) else {
      guard NSWorkspace.shared.open(adapter.installationURL) else {
        throw ProviderAuthenticationError.couldNotOpen(provider)
      }
      return
    }

    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appending(path: "org.openspotlight.app/auth", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let scriptURL = directory.appending(path: "connect-\(provider.rawValue).command")
    let command = ([executableURL.path] + adapter.authenticationLaunchArguments)
      .map(Self.shellQuote)
      .joined(separator: " ")
    let script = """
      #!/bin/zsh
      clear
      printf '\\e]0;Open Spotlight - Connect \(provider.displayName)\\a'
      echo 'Connect \(provider.displayName) to Open Spotlight'
      echo
      \(command)
      result=$?
      echo
      if [ $result -eq 0 ]; then
        echo 'Connected. You can return to Open Spotlight.'
      else
        echo 'Connection did not complete. Exit code:' $result
      fi
      echo
      read -k 1 '?Press any key to close this window.'
      """
    try Data(script.utf8).write(to: scriptURL, options: .atomic)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: scriptURL.path
    )
    guard NSWorkspace.shared.open(scriptURL) else {
      throw ProviderAuthenticationError.couldNotOpen(provider)
    }
  }

  private static func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}

private enum ProviderAuthenticationError: LocalizedError {
  case couldNotOpen(ProviderIdentifier)

  var errorDescription: String? {
    switch self {
    case .couldNotOpen(let provider):
      "Could not open the \(provider.displayName) connection flow."
    }
  }
}
