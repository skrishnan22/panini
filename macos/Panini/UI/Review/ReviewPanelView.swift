import AppKit
import SwiftUI

struct ReviewPanelView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var session: ReviewSession

    let onApply: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            ReviewPreviewCard(
                phase: session.phase,
                statusTitle: session.statusTitle,
                statusSubtitle: session.statusSubtitle,
                canCopy: session.canCopy,
                previewSegments: session.previewSegments,
                showsChangeList: session.showsChangeList,
                theme: theme,
                onCopy: copyPreviewText
            )

            if session.showsChangeList {
                ReviewChangeSection(
                    summaryText: session.changeSummaryText,
                    visibleChanges: session.visibleChanges,
                    disabledChangeIDs: session.disabledChangeIDs,
                    theme: theme,
                    onToggle: session.toggle
                )
            }

            Spacer(minLength: 0)
            ReviewPanelFooter(
                phase: session.phase,
                footerHint: footerHint,
                theme: theme,
                onApply: onApply,
                onCancel: onCancel,
                onRetry: onRetry
            )
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            TrianglePointer()
                .fill(theme.pointerFill)
                .frame(width: 14, height: 10)
                .overlay {
                    TrianglePointer()
                        .stroke(theme.panelBorder, lineWidth: 1)
                }
                .offset(x: 28, y: -9)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Panini")
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundColor(theme.primaryText)

            Spacer()

            Text(session.changeCountLabel)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(theme.secondaryText)
        }
    }

    private var footerHint: String {
        switch session.phase {
        case .loading, .ready:
            return "Esc to cancel"
        case .empty:
            return ""
        case .failed:
            return "Try again or cancel"
        }
    }

    private var previewAttributedText: AttributedString {
        var text = AttributedString()

        for segment in session.previewSegments {
            var part = AttributedString(segment.text)
            part.font = .system(size: 14, weight: .medium, design: .serif)
            part.foregroundColor = theme.primaryText

            if segment.isHighlighted {
                part.backgroundColor = theme.highlightFill
            }

            text.append(part)
        }

        return text
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

    private func copyPreviewText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.previewText, forType: .string)
    }

    private var theme: ReviewPanelTheme {
        colorScheme == .dark ? .dark : .light
    }
}
