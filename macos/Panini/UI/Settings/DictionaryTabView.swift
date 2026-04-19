import SwiftUI

struct DictionaryTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsTheme.sectionSpacing) {
                addWordSection
                wordListSection
                if let error = viewModel.lastError {
                    errorBanner(message: error)
                }
            }
            .padding(20)
        }
        .task { await viewModel.loadDictionary() }
    }

    // MARK: - Add Word

    private var addWordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Add Word")
            SettingsCard {
                HStack(spacing: 8) {
                    TextField("New word or phrase", text: $viewModel.newDictionaryWord)
                        .textFieldStyle(.plain)
                        .font(SettingsTheme.bodyFont)
                        .onSubmit {
                            Task { await viewModel.addDictionaryWord() }
                        }
                    Divider()
                        .frame(height: 20)
                    Button("Add") {
                        Task { await viewModel.addDictionaryWord() }
                    }
                    .disabled(viewModel.newDictionaryWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.plain)
                    .foregroundColor(
                        viewModel.newDictionaryWord.trimmingCharacters(in: .whitespaces).isEmpty
                        ? .secondary
                        : SettingsTheme.accent
                    )
                    .font(.system(size: 13, weight: .medium))
                }
                .padding(SettingsTheme.cardPadding)
            }
        }
    }

    // MARK: - Word List

    private var wordListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: "Words")
                Spacer()
                if !viewModel.dictionaryWords.isEmpty {
                    Text("\(viewModel.dictionaryWords.count) \(viewModel.dictionaryWords.count == 1 ? "word" : "words")")
                        .font(SettingsTheme.captionFont)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.dictionaryWords.isEmpty {
                emptyState
            } else {
                SettingsCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.dictionaryWords.enumerated()), id: \.element) { index, word in
                            if index > 0 {
                                Divider().padding(.horizontal, SettingsTheme.cardPadding)
                            }
                            HStack {
                                Text(word)
                                    .font(SettingsTheme.bodyFont)
                                Spacer()
                                Button {
                                    Task { await viewModel.removeDictionaryWord(word) }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(SettingsTheme.cardPadding)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Your dictionary is empty")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("Add words that Panini should always keep as-is.")
                .font(SettingsTheme.captionFont)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 14))
            Text(message)
                .font(SettingsTheme.captionFont)
                .foregroundColor(.red)
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
