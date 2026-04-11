import SwiftUI

// MARK: - Theme Constants

enum SettingsTheme {
    // Colors
    static let accent = Color(hex: "#4c8f52")
    static let sectionHeaderColor = Color(hex: "#8a8478")
    static let cardBackground = Color.white
    static let cardBorder = Color(hex: "#dddddd")
    static let destructive = Color.red

    // Dark-mode adaptive card background
    static func cardBG(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.15) : Color.white
    }

    static func cardBorderColor(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.28) : Color(hex: "#dddddd")
    }

    // Fonts
    static let sectionHeaderFont = Font.custom("Georgia", size: 11).weight(.regular)
    static let bodyFont = Font.system(size: 13)
    static let captionFont = Font.system(size: 11)

    // Spacing
    static let sectionSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 14
    static let rowSpacing: CGFloat = 10
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(SettingsTheme.sectionHeaderFont)
            .foregroundColor(SettingsTheme.sectionHeaderColor)
            .kerning(0.8)
    }
}

// MARK: - SettingsCard

struct SettingsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(SettingsTheme.cardBG(colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(SettingsTheme.cardBorderColor(colorScheme), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - PresetPill

struct PresetPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.primary.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? SettingsTheme.accent : Color.primary.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? SettingsTheme.accent : Color.primary.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - StatusDot

struct StatusDot: View {
    enum DotState {
        case healthy, warning, error, neutral
        var color: Color {
            switch self {
            case .healthy: return SettingsTheme.accent
            case .warning: return .orange
            case .error: return .red
            case .neutral: return .gray
            }
        }
    }

    let state: DotState

    var body: some View {
        Circle()
            .fill(state.color)
            .frame(width: 7, height: 7)
    }
}

// MARK: - ModelBadge

struct ModelBadge: View {
    enum BadgeStyle {
        case recommended, defaultModel, ready, downloading

        var label: String {
            switch self {
            case .recommended: return "Recommended"
            case .defaultModel: return "Default"
            case .ready: return "Ready"
            case .downloading: return "Downloading"
            }
        }

        var bgColor: Color {
            switch self {
            case .recommended: return SettingsTheme.accent.opacity(0.15)
            case .defaultModel: return Color.blue.opacity(0.12)
            case .ready: return SettingsTheme.accent.opacity(0.12)
            case .downloading: return Color.orange.opacity(0.12)
            }
        }

        var fgColor: Color {
            switch self {
            case .recommended: return SettingsTheme.accent
            case .defaultModel: return Color.blue
            case .ready: return SettingsTheme.accent
            case .downloading: return Color.orange
            }
        }
    }

    let style: BadgeStyle

    var body: some View {
        Text(style.label.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(style.fgColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(style.bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .kerning(0.5)
    }
}

// MARK: - DownloadProgressBar

struct DownloadProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [SettingsTheme.accent, SettingsTheme.accent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
                totalHeight = y
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.maxX
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
