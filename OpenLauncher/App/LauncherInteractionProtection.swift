struct LauncherInteractionProtection: Equatable {
    private(set) var isExternalInteractionInProgress = false
    private var didLeaveApplication = false

    mutating func beginExternalInteraction() {
        isExternalInteractionInProgress = true
        didLeaveApplication = false
    }

    mutating func applicationDidResignActive() {
        guard isExternalInteractionInProgress else { return }
        didLeaveApplication = true
    }

    mutating func applicationDidBecomeActive() -> Bool {
        guard isExternalInteractionInProgress, didLeaveApplication else { return false }
        isExternalInteractionInProgress = false
        didLeaveApplication = false
        return true
    }

    mutating func cancelExternalInteraction() {
        isExternalInteractionInProgress = false
        didLeaveApplication = false
    }

    func shouldDismissOutsideClick(
        preferenceEnabled: Bool,
        panelVisible: Bool,
        hasModalWindow: Bool,
        clickIsInsidePanel: Bool,
        runState: ProviderRunState
    ) -> Bool {
        preferenceEnabled
            && panelVisible
            && !hasModalWindow
            && !clickIsInsidePanel
            && runState != .streaming
            && !isExternalInteractionInProgress
    }
}
