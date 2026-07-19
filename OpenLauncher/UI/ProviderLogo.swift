import SwiftUI

struct ProviderLogo: View {
    let provider: ProviderIdentifier
    var size: CGFloat = 24

    var body: some View {
        Image(provider.logoAssetName)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }
}
