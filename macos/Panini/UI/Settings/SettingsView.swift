import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Backend") {
                LabeledContent("Provider") { Text(viewModel.backendLabel) }
                LabeledContent("Preset") { Text(viewModel.preset) }
                LabeledContent("Review Hotkey") { Text(viewModel.reviewHotkey) }
                LabeledContent("Auto-fix Hotkey") { Text(viewModel.autofixHotkey) }
                LabeledContent("Server Status") {
                    Text(viewModel.serverStatus)
                        .foregroundColor(viewModel.serverStatus == "Healthy" ? Color.green : Color.red)
                }
            }

            Section("Accessibility") {
                if viewModel.accessibilityGranted {
                    Text("Accessibility permission is granted.")
                        .foregroundColor(.green)
                } else {
                    Text("Grant Accessibility permission for reliable direct text replacement.")
                    HStack {
                        Button("Request Accessibility Permission") {
                            viewModel.requestAccessibilityPermission()
                        }
                        Button("Open System Settings") {
                            viewModel.openSystemSettings()
                        }
                    }
                }
            }

            Section("Dictionary") {
                HStack {
                    TextField("Add word", text: $viewModel.newDictionaryWord)
                    Button("Add") {
                        Task { await viewModel.addDictionaryWord() }
                    }
                }

                List(viewModel.dictionaryWords, id: \.self) { word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button("Remove") {
                            Task { await viewModel.removeDictionaryWord(word) }
                        }
                    }
                }
                .frame(minHeight: 120)
            }

            if let lastError = viewModel.lastError {
                Section("Errors") {
                    Text(lastError)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
        }
        .padding(16)
        .task {
            viewModel.refreshPermission()
            await viewModel.refreshServerHealth()
            await viewModel.loadDictionary()
        }
    }
}
