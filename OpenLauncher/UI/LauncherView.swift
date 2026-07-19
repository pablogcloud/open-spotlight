import AppKit
import SwiftUI

enum LauncherMetrics {
  static let surfaceWidth: CGFloat = 640
  static let controlSize: CGFloat = 56
  static let providerGap: CGFloat = 8
  static let suggestionRowHeight: CGFloat = 52
  static let resultGap: CGFloat = 10
}

struct LauncherProviderRevealGeometry: Equatable {
  let progress: CGFloat

  private var clampedProgress: CGFloat { min(max(progress, 0), 1) }

  private var emergence: CGFloat { smoothstep(0.16, 0.78, clampedProgress) }

  var searchWidth: CGFloat {
    if clampedProgress < 0.16 {
      let seamRetraction = smoothstep(0, 0.16, clampedProgress)
      return LauncherMetrics.surfaceWidth
        - LauncherMetrics.controlSize / 2 * seamRetraction
    }
    let detachmentGap = LauncherMetrics.providerGap * smoothstep(0.58, 1, emergence)
    return providerOffset - detachmentGap
  }

  var providerWidth: CGFloat {
    let growth = smoothstep(0, 0.42, emergence)
    let separation = smoothstep(0.34, 0.72, emergence)
    return LauncherMetrics.controlSize * (0.72 * growth + 0.28 * separation)
      - 1.5 * recoilWave(emergence)
  }

  var providerHeight: CGFloat {
    let growth = smoothstep(0, 0.42, emergence)
    return min(
      LauncherMetrics.controlSize,
      LauncherMetrics.controlSize * growth + 1.5 * recoilWave(emergence)
    )
  }

  var providerOffset: CGFloat {
    let originalCapCenter = LauncherMetrics.surfaceWidth - LauncherMetrics.controlSize / 2
    return originalCapCenter - providerWidth / 2
  }

}

struct LauncherView: View {
  @Bindable var model: LauncherViewModel
  @FocusState private var promptFocused: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var glassNamespace
  @State private var isSearchIconHovered = false
  @State private var isSurfaceHovered = false
  @State private var isProviderRevealArmed = false
  @State private var isProviderContentVisible = false
  @State private var providerDropletProgress: CGFloat = 0
  @State private var providerCycleMorph: CGFloat = 1
  @State private var providerLogoScale: CGFloat = 1
  @State private var providerLogoOpacity: CGFloat = 1
  @State private var isProviderCycling = false
  @State private var isPresented = false
  @State private var pendingHoverCollapse: Task<Void, Never>?
  @State private var pendingProviderMorph: Task<Void, Never>?
  @State private var pendingProviderContentReveal: Task<Void, Never>?
  @State private var pendingProviderCycle: Task<Void, Never>?

  private let surfaceWidth = LauncherMetrics.surfaceWidth
  private let providerControlSize = LauncherMetrics.controlSize

  var body: some View {
    spotlightSurface
      .frame(width: surfaceWidth, height: model.preferredSurfaceHeight, alignment: .top)
      .contentShape(Rectangle())
      .scaleEffect(isPresented || reducesMotion ? 1 : 0.975, anchor: .top)
      .opacity(isPresented ? 1 : 0)
      .onHover(perform: handleSurfaceHover)
      .onAppear {
        promptFocused = true
        reveal()
      }
      .onChange(of: model.promptFocusToken) { _, _ in promptFocused = true }
      .onChange(of: model.presentationToken) { _, _ in reveal() }
      .onChange(of: model.preferences.revealProviderOnHover) { _, enabled in
        if !enabled { hideProviderControl() }
      }
      .onDisappear {
        pendingHoverCollapse?.cancel()
        pendingProviderMorph?.cancel()
        pendingProviderContentReveal?.cancel()
        pendingProviderCycle?.cancel()
      }
      .onExitCommand { model.cancelOrClose() }
      .onKeyPress(
        keys: Set(["1", "2", "3"].map { KeyEquivalent(Character($0)) }),
        phases: .down,
        action: handleProviderShortcut
      )
      .onKeyPress(
        keys: [.upArrow, .downArrow, .return],
        phases: .down,
        action: handleSuggestionShortcut
      )
      .animation(surfaceAnimation, value: model.runState)
      .animation(surfaceAnimation, value: model.selectedFile)
      .animation(surfaceAnimation, value: isSearchIconHovered)
  }

  @ViewBuilder
  private var spotlightSurface: some View {
    surfaceStack
  }

  private var surfaceStack: some View {
    VStack(spacing: 10) {
      topBar

      if model.preferredSurfaceHeight > LauncherMetrics.controlSize {
        resultSurface
          .transition(
            reducesMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
      }
    }
  }

  private var topBar: some View {
    ZStack(alignment: .leading) {
      topBarGlass
      topBarContent
    }
    .frame(width: surfaceWidth, height: providerControlSize, alignment: .leading)
  }

  @ViewBuilder
  private var topBarGlass: some View {
    if #available(macOS 26.0, *) {
      GlassEffectContainer(spacing: 6) {
        glassShapes
      }
    } else {
      glassShapes
    }
  }

  private var glassShapes: some View {
    ZStack(alignment: .leading) {
      searchGlass
        .frame(width: searchWidth)

      if showsTrailingControl {
        providerGlassLayer
          .offset(x: providerDropletOffset)
      }
    }
    .frame(width: surfaceWidth, height: providerControlSize, alignment: .leading)
    .allowsHitTesting(false)
  }

  private var topBarContent: some View {
    ZStack(alignment: .leading) {
      searchContent
        .frame(width: searchWidth)

      trailingControl
        .frame(width: providerControlSize, height: providerControlSize)
        .opacity(showsProviderContent ? 1 : 0)
        .scaleEffect(showsProviderContent || reducesMotion ? 1 : 0.92, anchor: .leading)
        .offset(
          x: providerOffset + (showsProviderContent || reducesMotion ? 0 : -providerControlSize / 2)
        )
        .allowsHitTesting(showsProviderContent)
        .accessibilityHidden(!showsProviderContent)
    }
    .frame(width: surfaceWidth, height: providerControlSize, alignment: .leading)
  }

  private var searchContent: some View {
    HStack(spacing: 14) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 26, weight: .regular))
        .foregroundStyle(isSearchIconHovered ? .primary : .secondary)
        .frame(width: 34, height: 44)
        .contentShape(Circle())
        .onHover { hovering in
          withAnimation(surfaceAnimation) {
            isSearchIconHovered = hovering
          }
          if hovering {
            cancelPendingHoverCollapse()
            if model.preferences.revealProviderOnHover { revealProviderControl() }
          }
        }
        .accessibilityHidden(true)

      TextField("Open Spotlight", text: $model.prompt)
        .textFieldStyle(.plain)
        .focusEffectDisabled()
        .font(.system(size: 28, weight: .regular))
        .focused($promptFocused)
        .onSubmit { model.submit() }
        .accessibilityLabel("Open Spotlight search")
        .accessibilityHint("Use Command-1 for Claude, Command-2 for Codex, or Command-3 for Grok.")
        .accessibilityAction(named: "Use Claude") { chooseProvider(.claude) }
        .accessibilityAction(named: "Use Codex") { chooseProvider(.codex) }
        .accessibilityAction(named: "Use Grok") { chooseProvider(.grok) }

      if model.runState == .streaming {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel("Waiting for \(model.selectedProvider.displayName)")
      }
    }
    .padding(.horizontal, 20)
    .frame(height: providerControlSize)
    .contentShape(Capsule())
  }

  private var searchGlass: some View {
    Color.clear
      .frame(height: providerControlSize)
      .spotlightGlass(
        in: Capsule(),
        interactive: true,
        contrast: model.preferences.glassContrast
      )
      .glassIdentity("search", namespace: glassNamespace)
      .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
  }

  private var providerGlassLayer: some View {
    Color.clear
      .frame(width: providerDropletWidth, height: providerDropletHeight)
      .spotlightGlass(
        in: SidewaysDropletShape(detachment: min(effectiveDropletProgress, providerCycleMorph)),
        interactive: true,
        contrast: model.preferences.glassContrast
      )
      .glassIdentity("provider", namespace: glassNamespace)
      .shadow(
        color: .black.opacity(0.14 * effectiveDropletProgress),
        radius: 12,
        y: 5
      )
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var trailingControl: some View {
    if model.runState == .streaming {
      Button(action: model.cancel) {
        Image(systemName: "stop.fill")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: providerControlSize, height: providerControlSize)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(.primary)
      .help("Stop")
      .accessibilityLabel("Stop response")
    } else {
      Button(action: cycleProvider) {
        ProviderLogo(provider: model.selectedProvider, size: 34)
          .saturation(model.selectedProviderNeedsSetup ? 0 : 1)
          .opacity((model.selectedProviderNeedsSetup ? 0.38 : 1) * providerLogoOpacity)
          .scaleEffect(providerLogoScale)
          .frame(width: providerControlSize, height: providerControlSize)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .help("Switch to \(model.selectedProvider.nextInCycle.displayName)")
      .accessibilityLabel("Provider: \(model.selectedProvider.displayName)")
      .accessibilityHint("Cycles to \(model.selectedProvider.nextInCycle.displayName)")
    }
  }

  private var resultSurface: some View {
    Group {
      if model.showsSuggestions {
        suggestionList
      } else if model.runState == .awaitingDisclosure {
        disclosureView
      } else if model.selectedFile != nil, model.runState == .ready {
        attachedFileView
      } else {
        responseView
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background {
      Color.clear
        .spotlightGlass(
          in: RoundedRectangle(cornerRadius: 26, style: .continuous),
          interactive: true,
          contrast: model.preferences.glassContrast
        )
        .materializingGlassIdentity("results", namespace: glassNamespace)
    }
    .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
  }

  private var suggestionList: some View {
    VStack(spacing: 0) {
      ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { index, suggestion in
        Button {
          model.activateSuggestion(at: index)
        } label: {
          HStack(spacing: 12) {
            suggestionIcon(suggestion)
              .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
              Text(suggestion.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
              if let subtitle = suggestion.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                  .font(.system(size: 12.5))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }

            Spacer(minLength: 8)

            if index == model.selectedSuggestionIndex, suggestion.action.invokesProvider {
              Text("⌘↩")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            } else if index == model.selectedSuggestionIndex {
              Image(systemName: "arrow.turn.down.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            }
          }
          .padding(.horizontal, 13)
          .frame(height: LauncherMetrics.suggestionRowHeight)
          .background(
            index == model.selectedSuggestionIndex ? Color.primary.opacity(0.075) : .clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
          if hovering { model.selectSuggestion(at: index) }
        }
        .accessibilityLabel(suggestion.title)
        .accessibilityHint(suggestion.subtitle ?? "Open")
      }
    }
    .padding(6)
  }

  @ViewBuilder
  private func suggestionIcon(_ suggestion: LauncherSuggestion) -> some View {
    switch suggestion.icon {
    case .file(let url):
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        .resizable()
        .aspectRatio(contentMode: .fit)
    case .system(let name):
      Image(systemName: name)
        .font(.system(size: 19, weight: .regular))
        .foregroundStyle(.secondary)
    case .provider(let provider):
      ProviderLogo(provider: provider, size: 28)
    }
  }

  @ViewBuilder
  private var responseView: some View {
    switch model.runState {
    case .streaming where model.response.isEmpty:
      ProgressView()
        .controlSize(.regular)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .streaming, .completed, .cancelled:
      ScrollView {
        Text(model.response)
          .font(.system(size: 17, weight: .regular))
          .lineSpacing(5)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(24)
      }
      .scrollIndicators(.automatic)
    case .failed:
      failureView
    case .empty:
      Text("No response")
        .font(.system(size: 17))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    default:
      EmptyView()
    }
  }

  private var attachedFileView: some View {
    HStack(spacing: 12) {
      Image(systemName: "doc.text")
        .font(.system(size: 18))
        .foregroundStyle(.secondary)
      Text(model.selectedFile?.url.lastPathComponent ?? "")
        .font(.system(size: 16, weight: .medium))
        .lineLimit(1)
      Spacer()
      Button(action: model.removeFile) {
        Image(systemName: "xmark")
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Remove attached file")
    }
    .padding(.horizontal, 22)
    .frame(maxHeight: .infinity)
  }

  private var disclosureView: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Send this file to \(model.selectedProvider.displayName)?")
        .font(.system(size: 18, weight: .semibold))

      if let file = model.selectedFile {
        Text(file.url.lastPathComponent)
          .font(.system(size: 16, weight: .medium))
          .lineLimit(1)
        Text(
          "\(file.contents.count.formatted()) characters, \(ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .file))"
        )
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        Text(model.selectedAdapterDisclosure.summary)
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()

      HStack {
        Button("Cancel", action: model.rejectDisclosure)
        Spacer()
        Button("Send", action: model.confirmFileAndSubmit)
          .keyboardShortcut(.return, modifiers: .command)
      }
      .buttonStyle(.bordered)
    }
    .padding(24)
  }

  private var failureView: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(failureTitle)
        .font(.system(size: 19, weight: .semibold))
      Text(failureMessage)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
        .lineLimit(3)
        .textSelection(.enabled)
      Spacer()
      if model.isProviderSetupInProgress {
        HStack(spacing: 10) {
          ProgressView()
            .controlSize(.small)
          Text("Finish connecting in Terminal, then return here.")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
      } else {
        HStack {
          if model.selectedProviderNeedsSetup {
            Button(
              "Connect \(model.selectedProvider.displayName)", action: model.requestProviderSetup)
          } else {
            Button("Try Again", action: model.retry)
          }
          Button("Check Again") { Task { await model.reprobeSelectedProvider() } }
        }
        .buttonStyle(.bordered)
      }
    }
    .padding(24)
  }

  private var failureTitle: String {
    switch model.failure?.kind {
    case .authentication: "Connect \(model.selectedProvider.displayName)"
    case .rateLimited: "Usage limit reached"
    case .permissionDenied: "Permission denied"
    default: "\(model.selectedProvider.displayName) is unavailable"
    }
  }

  private var failureMessage: String {
    if let message = model.failure?.message { return message }
    return switch model.selectedDescriptor?.status {
    case .authenticationRequired: "Authentication is required before this provider can answer."
    case .unavailable(let reason): reason
    default: "Try checking the provider again."
    }
  }

  private var showsTrailingControl: Bool {
    isProviderRevealArmed || model.runState == .streaming || model.selectedProviderNeedsSetup
  }

  private var showsProviderContent: Bool {
    isProviderContentVisible || model.runState == .streaming || model.selectedProviderNeedsSetup
  }

  private var searchWidth: CGFloat {
    guard showsTrailingControl else { return surfaceWidth }
    return providerRevealGeometry.searchWidth
  }

  private var providerOffset: CGFloat {
    surfaceWidth - providerControlSize
  }

  private var hasPersistentTrailingControl: Bool {
    model.runState == .streaming || model.selectedProviderNeedsSetup || isProviderCycling
  }

  private var effectiveDropletProgress: CGFloat {
    hasPersistentTrailingControl || reducesMotion ? 1 : providerDropletProgress
  }

  private var providerDropletWidth: CGFloat {
    providerRevealGeometry.providerWidth
  }

  private var providerDropletHeight: CGFloat {
    providerRevealGeometry.providerHeight
  }

  private var providerDropletOffset: CGFloat {
    providerRevealGeometry.providerOffset
  }

  private var providerRevealGeometry: LauncherProviderRevealGeometry {
    LauncherProviderRevealGeometry(progress: effectiveDropletProgress)
  }

  private func chooseProvider(_ provider: ProviderIdentifier) {
    resetProviderCycle()
    model.activateProvider(provider)
  }

  private func cycleProvider() {
    guard !isProviderCycling else { return }
    let nextProvider = model.selectedProvider.nextInCycle

    guard !reducesMotion else {
      model.activateProvider(nextProvider)
      return
    }

    isProviderCycling = true
    cancelPendingHoverCollapse()
    pendingProviderCycle?.cancel()
    withAnimation(.easeIn(duration: 0.075)) {
      providerCycleMorph = 0
      providerLogoScale = 0.42
      providerLogoOpacity = 0
    }

    pendingProviderCycle = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(72))
      guard !Task.isCancelled else { return }
      model.activateProvider(nextProvider)
      withAnimation(.spring(response: 0.16, dampingFraction: 0.8)) {
        providerCycleMorph = 1
        providerLogoScale = 1
        providerLogoOpacity = 1
      }
      try? await Task.sleep(for: .milliseconds(170))
      guard !Task.isCancelled else { return }
      isProviderCycling = false
      pendingProviderCycle = nil
      if !isSurfaceHovered {
        beginProviderCollapse(after: .milliseconds(80))
      }
    }
  }

  private func resetProviderCycle() {
    pendingProviderCycle?.cancel()
    pendingProviderCycle = nil
    isProviderCycling = false
    providerCycleMorph = 1
    providerLogoScale = 1
    providerLogoOpacity = 1
  }

  private func handleProviderShortcut(_ press: KeyPress) -> KeyPress.Result {
    guard press.modifiers.contains(.command),
      let index = Int(press.characters),
      ProviderIdentifier.allCases.indices.contains(index - 1)
    else { return .ignored }
    chooseProvider(ProviderIdentifier.allCases[index - 1])
    return .handled
  }

  private func handleSuggestionShortcut(_ press: KeyPress) -> KeyPress.Result {
    if press.key == .return, press.modifiers.contains(.command) {
      if model.runState == .awaitingDisclosure {
        model.confirmFileAndSubmit()
      } else {
        model.submitToProvider()
      }
      return .handled
    }
    guard model.showsSuggestions else { return .ignored }
    switch press.key {
    case .upArrow:
      model.moveSuggestionSelection(by: -1)
      return .handled
    case .downArrow:
      model.moveSuggestionSelection(by: 1)
      return .handled
    default:
      return .ignored
    }
  }

  private var surfaceAnimation: Animation {
    reducesMotion ? .easeOut(duration: 0.08) : .spring(response: 0.34, dampingFraction: 0.86)
  }

  private var dropletPinchAnimation: Animation {
    reducesMotion
      ? .easeOut(duration: 0.08)
      : .spring(response: 0.25, dampingFraction: 0.82, blendDuration: 0.03)
  }

  private var dropletReturnAnimation: Animation {
    reducesMotion ? .easeOut(duration: 0.06) : .spring(response: 0.2, dampingFraction: 0.9)
  }

  private var providerContentAnimation: Animation {
    reducesMotion ? .easeOut(duration: 0.08) : .spring(response: 0.18, dampingFraction: 0.9)
  }

  private var providerExitAnimation: Animation {
    reducesMotion ? .easeOut(duration: 0.06) : .easeOut(duration: 0.14)
  }

  private var reducesMotion: Bool {
    reduceMotion || model.preferences.reduceMotion
  }

  private func reveal() {
    resetProviderCycle()
    pendingHoverCollapse?.cancel()
    pendingProviderMorph?.cancel()
    pendingProviderContentReveal?.cancel()
    if !hasPersistentTrailingControl {
      isProviderRevealArmed = false
      isProviderContentVisible = false
      providerDropletProgress = 0
    }

    if reducesMotion {
      isPresented = true
    } else {
      isPresented = false
      DispatchQueue.main.async {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
          isPresented = true
        }
      }
    }
  }

  private func handleSurfaceHover(_ hovering: Bool) {
    isSurfaceHovered = hovering
    if hovering {
      cancelPendingHoverCollapse()
      if isProviderRevealArmed, !showsProviderContent {
        animateProviderMorph()
        withAnimation(providerContentAnimation) { isProviderContentVisible = true }
      }
      return
    }

    beginProviderCollapse(after: .milliseconds(140))
  }

  private func beginProviderCollapse(after delay: Duration) {
    guard !hasPersistentTrailingControl else { return }
    pendingProviderContentReveal?.cancel()
    pendingProviderContentReveal = nil
    pendingProviderMorph?.cancel()
    pendingProviderMorph = nil
    pendingHoverCollapse?.cancel()
    pendingHoverCollapse = Task { @MainActor in
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled else { return }
      withAnimation(providerExitAnimation) {
        isProviderContentVisible = false
        isSearchIconHovered = false
      }

      withAnimation(dropletReturnAnimation) { providerDropletProgress = 0 }
      try? await Task.sleep(for: .milliseconds(reducesMotion ? 0 : 72))
      guard !Task.isCancelled else { return }
      isProviderRevealArmed = false
      pendingHoverCollapse = nil
    }
  }

  private func revealProviderControl() {
    pendingProviderContentReveal?.cancel()

    if reducesMotion {
      isProviderRevealArmed = true
      providerDropletProgress = 1
      isProviderContentVisible = true
      return
    }

    providerDropletProgress = 0
    isProviderRevealArmed = true
    animateProviderMorph()
    pendingProviderContentReveal = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(52))
      guard !Task.isCancelled else { return }
      withAnimation(providerContentAnimation) { isProviderContentVisible = true }
      pendingProviderContentReveal = nil
    }
  }

  private func animateProviderMorph() {
    pendingProviderMorph?.cancel()
    pendingProviderMorph = Task { @MainActor in
      await Task.yield()
      guard !Task.isCancelled else { return }
      withAnimation(dropletPinchAnimation) { providerDropletProgress = 1 }
      pendingProviderMorph = nil
    }
  }

  private func hideProviderControl() {
    beginProviderCollapse(after: .zero)
  }

  private func cancelPendingHoverCollapse() {
    pendingHoverCollapse?.cancel()
    pendingHoverCollapse = nil
  }
}

private struct SidewaysDropletShape: Shape {
  var detachment: CGFloat

  var animatableData: CGFloat {
    get { detachment }
    set { detachment = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let t = min(max(detachment, 0), 1)
    let rounding = smoothstep(0.42, 0.82, t)

    func point(_ droplet: CGPoint, _ circle: CGPoint) -> CGPoint {
      CGPoint(
        x: rect.minX + (droplet.x + (circle.x - droplet.x) * rounding) * rect.width,
        y: rect.minY + (droplet.y + (circle.y - droplet.y) * rounding) * rect.height
      )
    }

    var path = Path()
    path.move(to: point(CGPoint(x: 0, y: 0.5), CGPoint(x: 0, y: 0.5)))
    path.addCurve(
      to: point(CGPoint(x: 0.53, y: 0.06), CGPoint(x: 0.5, y: 0)),
      control1: point(CGPoint(x: 0.17, y: 0.49), CGPoint(x: 0, y: 0.224)),
      control2: point(CGPoint(x: 0.25, y: 0.06), CGPoint(x: 0.224, y: 0))
    )
    path.addCurve(
      to: point(CGPoint(x: 1, y: 0.5), CGPoint(x: 1, y: 0.5)),
      control1: point(CGPoint(x: 0.8, y: 0.06), CGPoint(x: 0.776, y: 0)),
      control2: point(CGPoint(x: 1, y: 0.24), CGPoint(x: 1, y: 0.224))
    )
    path.addCurve(
      to: point(CGPoint(x: 0.53, y: 0.94), CGPoint(x: 0.5, y: 1)),
      control1: point(CGPoint(x: 1, y: 0.76), CGPoint(x: 1, y: 0.776)),
      control2: point(CGPoint(x: 0.8, y: 0.94), CGPoint(x: 0.776, y: 1))
    )
    path.addCurve(
      to: point(CGPoint(x: 0, y: 0.5), CGPoint(x: 0, y: 0.5)),
      control1: point(CGPoint(x: 0.25, y: 0.94), CGPoint(x: 0.224, y: 1)),
      control2: point(CGPoint(x: 0.17, y: 0.51), CGPoint(x: 0, y: 0.776))
    )
    path.closeSubpath()
    return path
  }
}

private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
  guard edge0 != edge1 else { return value < edge0 ? 0 : 1 }
  let t = min(max((value - edge0) / (edge1 - edge0), 0), 1)
  return t * t * (3 - 2 * t)
}

private func recoilWave(_ value: CGFloat) -> CGFloat {
  let t = min(max((value - 0.72) / 0.28, 0), 1)
  return sin(.pi * t)
}

extension View {
  @ViewBuilder
  fileprivate func spotlightGlass<S: Shape>(
    in shape: S,
    interactive: Bool,
    contrast: LauncherGlassContrast
  ) -> some View {
    if #available(macOS 26.0, *) {
      glassEffect(
        .regular
          .tint(
            Color(nsColor: .windowBackgroundColor).opacity(
              contrast == .increased ? 0.56 : 0.42
            )
          )
          .interactive(interactive),
        in: shape
      )
    } else {
      background(.regularMaterial, in: shape)
        .overlay {
          shape
            .fill(
              Color(nsColor: .windowBackgroundColor).opacity(
                contrast == .increased ? 0.14 : 0.04
              )
            )
            .allowsHitTesting(false)
        }
        .overlay {
          shape.stroke(
            Color.primary.opacity(contrast == .increased ? 0.24 : 0.15),
            lineWidth: 1
          )
        }
    }
  }

  @ViewBuilder
  fileprivate func glassIdentity(_ id: String, namespace: Namespace.ID) -> some View {
    if #available(macOS 26.0, *) {
      glassEffectID(id, in: namespace)
        .glassEffectTransition(.matchedGeometry)
    } else {
      self
    }
  }

  @ViewBuilder
  fileprivate func materializingGlassIdentity(_ id: String, namespace: Namespace.ID) -> some View {
    if #available(macOS 26.0, *) {
      glassEffectID(id, in: namespace)
        .glassEffectTransition(.materialize)
    } else {
      self
    }
  }
}
