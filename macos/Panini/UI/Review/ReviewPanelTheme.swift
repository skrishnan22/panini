import SwiftUI

struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ReviewPanelTheme {
    let panelBackground: LinearGradient
    let panelBorder: Color
    let innerBorder: Color
    let pointerFill: Color
    let previewBackground: Color
    let previewBorder: Color
    let copyBackground: Color
    let copyBorder: Color
    let copyIcon: Color
    let highlightFill: Color
    let changeDot: Color
    let chipEnabledBackground: Color
    let chipEnabledBorder: Color
    let chipDisabledBackground: Color
    let chipDisabledBorder: Color
    let primaryButtonBackground: LinearGradient
    let primaryButtonBorder: Color
    let primaryButtonText: Color
    let primaryText: Color
    let secondaryText: Color
    let skeletonFill: Color
    let warningColor: Color
    let shadowColor: Color

    static let light = ReviewPanelTheme(
        panelBackground: LinearGradient(
            colors: [
                Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.92),
                Color(red: 0.969, green: 0.973, blue: 0.984, opacity: 0.96)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        panelBorder: Color(red: 0.384, green: 0.424, blue: 0.506, opacity: 0.16),
        innerBorder: Color.white.opacity(0.45),
        pointerFill: Color(red: 0.985, green: 0.988, blue: 0.995),
        previewBackground: Color(red: 0.961, green: 0.969, blue: 0.984, opacity: 0.92),
        previewBorder: Color(red: 0.4, green: 0.447, blue: 0.541, opacity: 0.12),
        copyBackground: Color.white.opacity(0.9),
        copyBorder: Color(red: 0.404, green: 0.455, blue: 0.553, opacity: 0.14),
        copyIcon: Color(red: 0.325, green: 0.384, blue: 0.486),
        highlightFill: Color(red: 0.565, green: 0.788, blue: 0.631, opacity: 0.24),
        changeDot: Color(red: 0.353, green: 0.659, blue: 0.435),
        chipEnabledBackground: Color(red: 0.965, green: 0.978, blue: 0.968, opacity: 0.82),
        chipEnabledBorder: Color(red: 0.353, green: 0.659, blue: 0.435, opacity: 0.24),
        chipDisabledBackground: Color(red: 0.946, green: 0.953, blue: 0.967, opacity: 0.82),
        chipDisabledBorder: Color(red: 0.404, green: 0.455, blue: 0.553, opacity: 0.12),
        primaryButtonBackground: LinearGradient(
            colors: [
                Color(red: 0.859, green: 0.914, blue: 1.0),
                Color(red: 0.741, green: 0.831, blue: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        primaryButtonBorder: Color(red: 0.459, green: 0.62, blue: 0.902, opacity: 0.4),
        primaryButtonText: Color(red: 0.094, green: 0.192, blue: 0.329),
        primaryText: Color(red: 0.094, green: 0.11, blue: 0.137),
        secondaryText: Color(red: 0.416, green: 0.447, blue: 0.506),
        skeletonFill: Color(red: 0.416, green: 0.447, blue: 0.506, opacity: 0.16),
        warningColor: Color(red: 0.76, green: 0.49, blue: 0.24),
        shadowColor: Color.black.opacity(0.18)
    )

    static let dark = ReviewPanelTheme(
        panelBackground: LinearGradient(
            colors: [
                Color(red: 0.169, green: 0.173, blue: 0.188),
                Color(red: 0.137, green: 0.141, blue: 0.161)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        panelBorder: Color.white.opacity(0.08),
        innerBorder: Color.white.opacity(0.04),
        pointerFill: Color(red: 0.165, green: 0.169, blue: 0.184),
        previewBackground: Color(red: 0.047, green: 0.051, blue: 0.063, opacity: 0.52),
        previewBorder: Color.white.opacity(0.07),
        copyBackground: Color.white.opacity(0.06),
        copyBorder: Color.white.opacity(0.08),
        copyIcon: Color(red: 0.808, green: 0.867, blue: 1.0),
        highlightFill: Color(red: 0.447, green: 0.804, blue: 0.506, opacity: 0.18),
        changeDot: Color(red: 0.475, green: 0.812, blue: 0.51),
        chipEnabledBackground: Color(red: 0.129, green: 0.137, blue: 0.133, opacity: 0.72),
        chipEnabledBorder: Color(red: 0.475, green: 0.812, blue: 0.51, opacity: 0.18),
        chipDisabledBackground: Color.white.opacity(0.05),
        chipDisabledBorder: Color.white.opacity(0.07),
        primaryButtonBackground: LinearGradient(
            colors: [
                Color(red: 0.769, green: 0.867, blue: 1.0),
                Color(red: 0.557, green: 0.725, blue: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        primaryButtonBorder: Color(red: 0.686, green: 0.796, blue: 1.0, opacity: 0.7),
        primaryButtonText: Color(red: 0.035, green: 0.067, blue: 0.114),
        primaryText: Color(red: 0.957, green: 0.957, blue: 0.965),
        secondaryText: Color(red: 0.608, green: 0.624, blue: 0.659),
        skeletonFill: Color.white.opacity(0.1),
        warningColor: Color(red: 0.914, green: 0.648, blue: 0.38),
        shadowColor: Color.black.opacity(0.34)
    )
}

struct OptionalKeyboardShortcut: ViewModifier {
    let shortcut: KeyEquivalent?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let shortcut {
            content.keyboardShortcut(shortcut, modifiers: [])
        } else {
            content
        }
    }
}
