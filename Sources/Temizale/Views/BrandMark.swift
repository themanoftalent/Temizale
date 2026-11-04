import SwiftUI

/// The "Ale" logo: a rounded tile with the wordmark, matching the app icon.
struct BrandMark: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Theme.heroGradient)
            Text(Brand.logoText)
                .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(size * 0.1)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.accentDeep.opacity(0.25), radius: size * 0.08, y: size * 0.04)
        .accessibilityLabel("\(Brand.appName) logo")
    }
}

/// Logo plus product name, shown at the top of the sidebar.
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            BrandMark(size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(Brand.appName)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .lineLimit(1)
                Text("by \(Brand.identity)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }
}
