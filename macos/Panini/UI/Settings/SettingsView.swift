import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralTabView(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gearshape") }
            ModelsTabView(viewModel: viewModel)
                .tabItem { Label("Models", systemImage: "arrow.down.circle") }
            CloudTabView(viewModel: viewModel)
                .tabItem { Label("Cloud", systemImage: "cloud") }
            HotkeysTabView(viewModel: viewModel)
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
            DictionaryTabView(viewModel: viewModel)
                .tabItem { Label("Dictionary", systemImage: "book") }
        }
        .task {
            viewModel.refreshPermission()
            await viewModel.refreshServerHealth()
        }
    }
}
