import SwiftUI

struct ReviewChangeSection: View {
    let summaryText: String
    let visibleChanges: [ReviewChange]
    let disabledChangeIDs: Set<UUID>
    let theme: ReviewPanelTheme
    let onToggle: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(theme.changeDot)
                    .frame(width: 9, height: 9)

                Text(summaryText)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)

                Spacer()
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8, alignment: .leading)], spacing: 8) {
                    ForEach(visibleChanges) { reviewChange in
                        changeChip(for: reviewChange)
                    }
                }
            }
            .frame(maxHeight: 80)
        }
    }

    private func changeChip(for reviewChange: ReviewChange) -> some View {
        let change = reviewChange.change
        let disabled = disabledChangeIDs.contains(reviewChange.id)

        return Button {
            onToggle(reviewChange.id)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: disabled ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(disabled ? theme.secondaryText : theme.changeDot)

                Text("\(change.originalText) → \(change.replacement)")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(disabled ? theme.secondaryText : theme.primaryText)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(disabled ? theme.chipDisabledBackground : theme.chipEnabledBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(disabled ? theme.chipDisabledBorder : theme.chipEnabledBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
