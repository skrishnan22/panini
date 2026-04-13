import SwiftUI

struct GeneralTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var statusExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsTheme.sectionSpacing) {
                backendSection
                if viewModel.backendChoice == .local {
                    modelSection
                }
                presetSection
                behaviorSection
                statusSection
            }
            .padding(20)
        }
    }

    // MARK: - Backend

    private var backendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Backend")
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Provider")
                            .font(SettingsTheme.bodyFont)
                        Spacer()
                        Picker("", selection: $viewModel.backendChoice) {
                            Text("Local").tag(BackendChoice.local)
                            Text("Cloud").tag(BackendChoice.cloud)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    .padding(SettingsTheme.cardPadding)

                    Divider().padding(.horizontal, SettingsTheme.cardPadding)

                    Text(viewModel.backendChoice == .local
                         ? "Uses a local MLX model. No data leaves your device."
                         : "Uses a remote cloud API. An API key is required.")
                        .font(SettingsTheme.captionFont)
                        .foregroundColor(.secondary)
                        .padding(SettingsTheme.cardPadding)
                }
            }
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Model")
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.downloadedModels.isEmpty {
                        HStack {
                            Text("No models downloaded")
                                .font(SettingsTheme.bodyFont)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Go to Models tab to download")
                                .font(SettingsTheme.captionFont)
                                .foregroundColor(.secondary)
                        }
                        .padding(SettingsTheme.cardPadding)
                    } else {
                        HStack {
                            Text("Active Model")
                                .font(SettingsTheme.bodyFont)
                            Spacer()
                            Picker("", selection: $viewModel.selectedModelID) {
                                ForEach(viewModel.downloadedModels) { model in
                                    Text(model.name).tag(model.id)
                                }
                            }
                            .fixedSize()
                        }
                        .padding(SettingsTheme.cardPadding)
                    }
                }
            }
        }
    }

    // MARK: - Default Preset

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Default Preset")
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.availablePresets) { preset in
                            PresetPill(
                                label: preset.name,
                                isSelected: viewModel.selectedPreset == preset.id
                            ) {
                                viewModel.selectedPreset = preset.id
                            }
                        }
                    }

                    if let preset = viewModel.availablePresets.first(where: { $0.id == viewModel.selectedPreset }) {
                        Text(preset.description)
                            .font(SettingsTheme.captionFont)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(SettingsTheme.cardPadding)
            }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Behavior")
            SettingsCard {
                Toggle(isOn: $viewModel.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(SettingsTheme.bodyFont)
                        Text("Panini will start automatically when you log in.")
                            .font(SettingsTheme.captionFont)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .padding(SettingsTheme.cardPadding)
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: "Status")
                Spacer()
                Button {
                    withAnimation { statusExpanded.toggle() }
                } label: {
                    Image(systemName: statusExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if statusExpanded {
                SettingsCard {
                    VStack(spacing: 0) {
                        statusRow(
                            label: "Provider",
                            value: viewModel.providerStatus,
                            dot: viewModel.backendChoice == .local ? .healthy : .warning
                        )
                        Divider().padding(.horizontal, SettingsTheme.cardPadding)
                        statusRow(
                            label: "Accessibility",
                            value: viewModel.accessibilityGranted ? "Granted" : "Not Granted",
                            dot: viewModel.accessibilityGranted ? .healthy : .warning,
                            action: viewModel.accessibilityGranted ? nil : {
                                viewModel.requestAccessibilityPermission()
                            },
                            actionLabel: "Grant"
                        )
                        if !viewModel.selectedModelID.isEmpty {
                            Divider().padding(.horizontal, SettingsTheme.cardPadding)
                            statusRow(
                                label: "Active Model",
                                value: viewModel.selectedModelID,
                                dot: .neutral
                            )
                        }
                    }
                }
            }
        }
    }

    private func statusRow(
        label: String,
        value: String,
        dot: StatusDot.DotState,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) -> some View {
        HStack {
            StatusDot(state: dot)
            Text(label)
                .font(SettingsTheme.bodyFont)
            Spacer()
            Text(value)
                .font(SettingsTheme.captionFont)
                .foregroundColor(.secondary)
            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .font(SettingsTheme.captionFont)
                    .buttonStyle(.borderless)
                    .foregroundColor(SettingsTheme.accent)
            }
        }
        .padding(SettingsTheme.cardPadding)
    }
}
