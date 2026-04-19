import SwiftUI

struct HotkeysTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsTheme.sectionSpacing) {
                if viewModel.hasHotkeyConflict {
                    conflictBanner
                }
                hotkeysSection
                resetSection
            }
            .padding(20)
        }
    }

    // MARK: - Conflict Banner

    private var conflictBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))
            Text("Two or more hotkeys share the same binding. Each action must have a unique shortcut.")
                .font(SettingsTheme.captionFont)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Hotkeys List

    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Keyboard Shortcuts")
            SettingsCard {
                VStack(spacing: 0) {
                    hotkeyRow(label: "Open Palette", binding: $viewModel.paletteHotkey)
                    Divider().padding(.horizontal, SettingsTheme.cardPadding)
                    hotkeyRow(label: "Quick Fix", binding: $viewModel.fixHotkey)
                    Divider().padding(.horizontal, SettingsTheme.cardPadding)
                    hotkeyRow(label: "Paraphrase", binding: $viewModel.paraphraseHotkey)
                    Divider().padding(.horizontal, SettingsTheme.cardPadding)
                    hotkeyRow(label: "Professional", binding: $viewModel.professionalHotkey)
                }
            }
        }
    }

    private func hotkeyRow(label: String, binding: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(SettingsTheme.bodyFont)
            Spacer()
            Picker("", selection: binding) {
                ForEach(viewModel.hotkeyOptions, id: \.self) { option in
                    Text(formatHotkey(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .labelsHidden()
        }
        .padding(SettingsTheme.cardPadding)
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Reset")
            SettingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset to Defaults")
                            .font(SettingsTheme.bodyFont)
                        Text("Restore all hotkeys to their original bindings.")
                            .font(SettingsTheme.captionFont)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Reset") {
                        viewModel.resetHotkeysToDefaults()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(SettingsTheme.destructive)
                    .font(.system(size: 13))
                }
                .padding(SettingsTheme.cardPadding)
            }
        }
    }

    // MARK: - Hotkey Formatter

    private func formatHotkey(_ raw: String) -> String {
        var result = raw
        result = result.replacingOccurrences(of: "cmd", with: "⌘")
        result = result.replacingOccurrences(of: "ctrl", with: "⌃")
        result = result.replacingOccurrences(of: "shift", with: "⇧")
        result = result.replacingOccurrences(of: "option", with: "⌥")
        result = result.replacingOccurrences(of: "+", with: "")
        result = result.uppercased()
        return result
    }
}
