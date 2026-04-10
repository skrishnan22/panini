import SwiftUI

struct CommandPaletteView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var session: ActionPaletteSession

    let onChoose: (SelectionAction) -> Void
    let onHighlight: (SelectionAction) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            actionList
            footer
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(width: 360, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.panelBackground)
                .shadow(color: theme.shadowColor, radius: 22, x: 0, y: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(theme.panelBorder, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .inset(by: 1)
                .strokeBorder(theme.innerBorder, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            CommandPaletteTrianglePointer()
                .fill(theme.pointerFill)
                .frame(width: 14, height: 10)
                .overlay {
                    CommandPaletteTrianglePointer()
                        .stroke(theme.panelBorder, lineWidth: 1)
                }
                .offset(x: 28, y: -9)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Choose an action")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(theme.primaryText)

            Text("Use arrow keys to move, Return to run, Esc to cancel.")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundColor(theme.secondaryText)
        }
    }

    private var actionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(session.visibleActions, id: \.self) { action in
                actionRow(for: action)
            }
        }
    }

    private func actionRow(for action: SelectionAction) -> some View {
        let isHighlighted = action == session.highlightedAction

        return Button {
            onChoose(action)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(isHighlighted ? theme.highlightAccent : theme.idleAccent)
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundColor(theme.primaryText)

                    Text(action.subtitle)
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if let badge = shortcutBadge(for: action) {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(isHighlighted ? theme.highlightBadgeText : theme.badgeText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isHighlighted ? theme.highlightBadgeBackground : theme.badgeBackground)
                        )
                        .overlay(
                            Capsule()
                                .stroke(isHighlighted ? theme.highlightBadgeBorder : theme.badgeBorder, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isHighlighted ? theme.highlightBackground : theme.rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isHighlighted ? theme.highlightBorder : theme.rowBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onHighlight(action) }
        )
        .onHover { hovering in
            if hovering {
                onHighlight(action)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("Direct hotkeys are available for Fix, Paraphrase, and Professional.")
                .font(.system(size: 11, weight: .regular, design: .serif))
                .foregroundColor(theme.secondaryText)

            Spacer()

            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(theme.secondaryText)
        }
    }

    private func shortcutBadge(for action: SelectionAction) -> String? {
        switch action {
        case .fix:
            return "⌥⇧⌘G"
        case .paraphrase:
            return "⌥⇧⌘P"
        case .professional:
            return "⌥⇧⌘M"
        case .improve, .casual:
            return nil
        }
    }

    private var theme: CommandPaletteTheme {
        CommandPaletteTheme(colorScheme: colorScheme)
    }
}

private struct CommandPaletteTrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CommandPaletteTheme {
    let panelBackground: Color
    let panelBorder: Color
    let innerBorder: Color
    let pointerFill: Color
    let primaryText: Color
    let secondaryText: Color
    let rowBackground: Color
    let rowBorder: Color
    let highlightBackground: Color
    let highlightBorder: Color
    let idleAccent: Color
    let highlightAccent: Color
    let badgeBackground: Color
    let badgeBorder: Color
    let badgeText: Color
    let highlightBadgeBackground: Color
    let highlightBadgeBorder: Color
    let highlightBadgeText: Color
    let shadowColor: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            panelBackground = Color(red: 0.13, green: 0.15, blue: 0.18)
            panelBorder = Color.white.opacity(0.16)
            innerBorder = Color.white.opacity(0.06)
            pointerFill = panelBackground
            primaryText = Color.white.opacity(0.95)
            secondaryText = Color.white.opacity(0.66)
            rowBackground = Color.white.opacity(0.03)
            rowBorder = Color.white.opacity(0.06)
            highlightBackground = Color(red: 0.23, green: 0.29, blue: 0.24)
            highlightBorder = Color(red: 0.54, green: 0.68, blue: 0.57).opacity(0.7)
            idleAccent = Color.white.opacity(0.24)
            highlightAccent = Color(red: 0.62, green: 0.81, blue: 0.66)
            badgeBackground = Color.white.opacity(0.05)
            badgeBorder = Color.white.opacity(0.08)
            badgeText = Color.white.opacity(0.68)
            highlightBadgeBackground = Color.black.opacity(0.18)
            highlightBadgeBorder = Color.white.opacity(0.16)
            highlightBadgeText = Color.white.opacity(0.92)
            shadowColor = Color.black.opacity(0.35)
        } else {
            panelBackground = Color(red: 0.979, green: 0.971, blue: 0.949)
            panelBorder = Color.black.opacity(0.1)
            innerBorder = Color.white.opacity(0.45)
            pointerFill = panelBackground
            primaryText = Color(red: 0.16, green: 0.14, blue: 0.11)
            secondaryText = Color(red: 0.37, green: 0.34, blue: 0.29)
            rowBackground = Color.white.opacity(0.58)
            rowBorder = Color.black.opacity(0.06)
            highlightBackground = Color(red: 0.90, green: 0.95, blue: 0.90)
            highlightBorder = Color(red: 0.44, green: 0.58, blue: 0.45).opacity(0.52)
            idleAccent = Color(red: 0.63, green: 0.60, blue: 0.55)
            highlightAccent = Color(red: 0.31, green: 0.53, blue: 0.35)
            badgeBackground = Color(red: 0.95, green: 0.93, blue: 0.89)
            badgeBorder = Color.black.opacity(0.07)
            badgeText = Color(red: 0.33, green: 0.31, blue: 0.27)
            highlightBadgeBackground = Color.white.opacity(0.72)
            highlightBadgeBorder = Color.black.opacity(0.08)
            highlightBadgeText = Color(red: 0.21, green: 0.28, blue: 0.22)
            shadowColor = Color.black.opacity(0.12)
        }
    }
}
