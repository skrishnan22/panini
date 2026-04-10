import SwiftUI

struct ReviewPreviewCard: View {
    let phase: ReviewSession.Phase
    let statusTitle: String
    let statusSubtitle: String
    let canCopy: Bool
    let previewSegments: [ReviewSession.PreviewSegment]
    let showsChangeList: Bool
    let theme: ReviewPanelTheme
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .frame(height: showsChangeList ? 132 : 146)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.previewBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.previewBorder, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(statusTitle)
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundColor(theme.secondaryText)

            Spacer()

            if canCopy {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.copyIcon)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(theme.copyBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(theme.copyBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Copy text")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            loadingContent
        case .ready, .empty:
            ScrollView(.vertical, showsIndicators: false) {
                Text(previewAttributedText)
                    .textSelection(.enabled)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .failed:
            failureContent
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(0 ..< 4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.skeletonFill)
                    .frame(width: index == 3 ? 174 : nil, height: 12)
            }

            Spacer()

            Text(statusSubtitle)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundColor(theme.secondaryText)
        }
    }

    private var failureContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.warningColor)

            Text(statusTitle)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundColor(theme.primaryText)

            Text(statusSubtitle)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewAttributedText: AttributedString {
        var text = AttributedString()

        for segment in previewSegments {
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
}
