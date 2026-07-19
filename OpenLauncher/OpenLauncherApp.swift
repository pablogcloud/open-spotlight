import AppKit

@main
enum OpenLauncherApp {
  @MainActor
  static func main() {
    let application = NSApplication.shared
    let delegate = LauncherApplicationDelegate()
    application.delegate = delegate
    application.run()
  }
}
