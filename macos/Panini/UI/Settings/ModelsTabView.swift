import SwiftUI

struct ModelsTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsTheme.sectionSpacing) {
                if !viewModel.hasAnyModelDownloaded {
                    nudgeBanner
                }
                modelListSection
            }
            .padding(20)
        }
        .task { await viewModel.loadModels() }
    }

    // MARK: - Nudge Banner

    private var nudgeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text("No model downloaded")
                    .font(.system(size: 13, weight: .semibold))
                Text("Download a model below to use the Local backend.")
                    .font(SettingsTheme.captionFont)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Model List

    private var modelListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Available Models")
            SettingsCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.models.enumerated()), id: \.element.id) { index, model in
                        if index > 0 {
                            Divider().padding(.horizontal, SettingsTheme.cardPadding)
                        }
                        ModelRowView(model: model, viewModel: viewModel)
                    }

                    if viewModel.models.isEmpty {
                        HStack {
                            Spacer()
                            Text("Loading models…")
                                .font(SettingsTheme.captionFont)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(SettingsTheme.cardPadding)
                    }
                }
            }

            // Storage footer
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(viewModel.totalDiskUsageLabel)
                    .font(SettingsTheme.captionFont)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - ModelRowView

private struct ModelRowView: View {
    let model: ModelEntry
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(model.name)
                    .font(.system(size: 13, weight: .medium))

                if model.isDefault {
                    ModelBadge(style: .defaultModel)
                }

                switch model.downloadStatus {
                case .ready:
                    ModelBadge(style: .ready)
                case .downloading:
                    ModelBadge(style: .downloading)
                case .notDownloaded:
                    EmptyView()
                }

                Spacer()

                actionButton
            }

            Text("\(model.params) · \(String(format: "%.1f", model.downloadSizeGB)) GB · \(model.ramGB) GB RAM")
                .font(SettingsTheme.captionFont)
                .foregroundColor(.secondary)

            if model.downloadStatus == .downloading {
                progressBar
            }
        }
        .padding(SettingsTheme.cardPadding)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch model.downloadStatus {
        case .notDownloaded:
            Button("Download") {
                Task { await viewModel.downloadModel(model.id) }
            }
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(.plain)
            .foregroundColor(SettingsTheme.accent)

        case .downloading:
            Button("Cancel") {
                Task { await viewModel.cancelDownload(model.id) }
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

        case .ready:
            Button("Delete") {
                Task { await viewModel.deleteModel(model.id) }
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundColor(SettingsTheme.destructive)
        }
    }

    private var progressBar: some View {
        VStack(alignment: .trailing, spacing: 4) {
            DownloadProgressBar(progress: model.downloadProgress ?? 0)
            if let dl = model.bytesDownloaded, let total = model.bytesTotal, total > 0 {
                Text("\(formatBytes(dl)) / \(formatBytes(total))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 0.1 {
            return String(format: "%.2f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}
