import SwiftUI

struct ReviewPanelFooter: View {
    let phase: ReviewSession.Phase
    let footerHint: String
    let theme: ReviewPanelTheme
    let onApply: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(footerHint)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundColor(theme.secondaryText)

            Spacer()

            switch phase {
            case .loading:
                ghostButton("Cancel", shortcut: .escape, action: onCancel)
            case .ready:
                HStack(spacing: 8) {
                    ghostButton("Cancel", shortcut: .escape, action: onCancel)
                    primaryButton("Apply", shortcut: .return, action: onApply)
                }
            case .empty:
                primaryButton("Done", action: onCancel)
            case .failed:
                HStack(spacing: 8) {
                    ghostButton("Cancel", shortcut: .escape, action: onCancel)
                    primaryButton("Retry", action: onRetry)
                }
            }
        }
    }

    private func primaryButton(
        _ title: String,
        shortcut: KeyEquivalent? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold, design: .serif))
            .foregroundColor(theme.primaryButtonText)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.primaryButtonBackground)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(theme.primaryButtonBorder, lineWidth: 1)
            )
            .modifier(OptionalKeyboardShortcut(shortcut: shortcut))
    }

    private func ghostButton(
        _ title: String,
        shortcut: KeyEquivalent? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium, design: .serif))
            .foregroundColor(theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .modifier(OptionalKeyboardShortcut(shortcut: shortcut))
    }
}
