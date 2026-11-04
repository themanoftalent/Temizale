import SwiftUI
import TemizCacheCore

enum Theme {
    static let accent = Color(red: 0.06, green: 0.58, blue: 0.62)
    static let accentDeep = Color(red: 0.07, green: 0.38, blue: 0.69)
    static let trash = Color(red: 0.86, green: 0.30, blue: 0.27)
    static let corner: CGFloat = 14

    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let cardBorder = Color.primary.opacity(0.07)
    static let canvas = Color(nsColor: .windowBackgroundColor)

    static func color(for kind: CacheTarget.Kind) -> Color {
        switch kind {
        case .developer: return Color(red: 0.36, green: 0.39, blue: 0.86)
        case .packageManager: return Color(red: 0.93, green: 0.55, blue: 0.16)
        case .browser: return Color(red: 0.16, green: 0.53, blue: 0.93)
        case .app: return Color(red: 0.86, green: 0.30, blue: 0.56)
        case .logs: return Color(red: 0.50, green: 0.53, blue: 0.58)
        case .custom: return accent
        }
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Rounded, softly bordered surface used for every card in the app.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardModifier(padding: padding)) }
}

/// Byte count with an animated digit transition.
struct BytesText: View {
    let bytes: Int64?
    var placeholder = "—"

    var body: some View {
        Text(bytes.map(ByteText.string) ?? placeholder)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy, value: bytes)
            .accessibilityLabel(bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Measuring")
    }
}

/// Colored circular badge with an SF Symbol.
struct IconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(color.gradient)
            )
            .accessibilityHidden(true)
    }
}

/// Ring gauge for a 0...1 fraction.
struct RingGauge: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 9

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: fraction)
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((fraction * 100).rounded())) percent used")
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}
