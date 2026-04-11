import SwiftUI

struct CloudTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var apiKeyRevealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsTheme.sectionSpacing) {
                if viewModel.backendChoice == .local {
                    switchToCloudPrompt
                } else {
                    apiKeySection
                    connectionSection
                }
            }
            .padding(20)
        }
    }

    // MARK: - Switch to Cloud Prompt

    private var switchToCloudPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                Text("Cloud Backend Not Active")
                    .font(.system(size: 15, weight: .semibold))
                Text("Switch to Cloud in the General tab to configure API settings.")
                    .font(SettingsTheme.captionFont)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "API Key")
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if apiKeyRevealed {
                            TextField("Enter API key", text: $viewModel.apiKey)
                                .font(.system(size: 13, design: .monospaced))
                                .textFieldStyle(.plain)
                        } else {
                            SecureField("Enter API key", text: $viewModel.apiKey)
                                .font(.system(size: 13, design: .monospaced))
                                .textFieldStyle(.plain)
                        }

                        Button {
                            apiKeyRevealed.toggle()
                        } label: {
                            Image(systemName: apiKeyRevealed ? "eye.slash" : "eye")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(SettingsTheme.cardPadding)

                    Divider().padding(.horizontal, SettingsTheme.cardPadding)

                    Text("Your API key is stored securely in the system keychain.")
                        .font(SettingsTheme.captionFont)
                        .foregroundColor(.secondary)
                        .padding(SettingsTheme.cardPadding)
                }
            }
        }
    }

    // MARK: - Connection Test Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Connection")
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Test Connection")
                                .font(SettingsTheme.bodyFont)
                            Text("Verify that your API key and backend are reachable.")
                                .font(SettingsTheme.captionFont)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        testStatusIndicator
                        Button("Test") {
                            Task { await viewModel.testConnection() }
                        }
                        .disabled(viewModel.connectionTestStatus == .testing)
                        .buttonStyle(.borderedProminent)
                        .tint(SettingsTheme.accent)
                        .font(.system(size: 12))
                    }
                    .padding(SettingsTheme.cardPadding)
                }
            }
        }
    }

    @ViewBuilder
    private var testStatusIndicator: some View {
        switch viewModel.connectionTestStatus {
        case .untested:
            EmptyView()
        case .testing:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 20, height: 20)
        case .connected:
            HStack(spacing: 4) {
                StatusDot(state: .healthy)
                Text("Connected")
                    .font(SettingsTheme.captionFont)
                    .foregroundColor(SettingsTheme.accent)
            }
        case .failed(let msg):
            HStack(spacing: 4) {
                StatusDot(state: .error)
                Text(msg)
                    .font(SettingsTheme.captionFont)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
    }
}
