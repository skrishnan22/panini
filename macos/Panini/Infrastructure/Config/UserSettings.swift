import Foundation

enum BackendChoice: String {
    case local
    case cloud
}

final class UserSettings: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            "defaultPreset": "fix",
            "backendChoice": BackendChoice.local.rawValue,
            "selectedModelID": LocalModelCatalog.defaultModelID,
            "launchAtLogin": false,
            "paletteHotkey": "cmd+shift+g",
            "fixHotkey": "cmd+shift+option+g",
            "paraphraseHotkey": "cmd+shift+option+p",
            "professionalHotkey": "cmd+shift+option+m",
        ])
    }

    var defaultPreset: String {
        get { defaults.string(forKey: "defaultPreset") ?? "fix" }
        set { defaults.set(newValue, forKey: "defaultPreset"); objectWillChange.send() }
    }

    var backendChoice: BackendChoice {
        get { BackendChoice(rawValue: defaults.string(forKey: "backendChoice") ?? "local") ?? .local }
        set { defaults.set(newValue.rawValue, forKey: "backendChoice"); objectWillChange.send() }
    }

    var selectedModelID: String {
        get {
            let current = defaults.string(forKey: "selectedModelID") ?? LocalModelCatalog.defaultModelID
            let migrated = LocalModelCatalog.migratedModelID(from: current)
            if migrated != current {
                defaults.set(migrated, forKey: "selectedModelID")
            }
            return migrated
        }
        set { defaults.set(newValue, forKey: "selectedModelID"); objectWillChange.send() }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin"); objectWillChange.send() }
    }

    var paletteHotkey: String {
        get { defaults.string(forKey: "paletteHotkey") ?? "cmd+shift+g" }
        set { defaults.set(newValue, forKey: "paletteHotkey"); objectWillChange.send() }
    }

    var fixHotkey: String {
        get { defaults.string(forKey: "fixHotkey") ?? "cmd+shift+option+g" }
        set { defaults.set(newValue, forKey: "fixHotkey"); objectWillChange.send() }
    }

    var paraphraseHotkey: String {
        get { defaults.string(forKey: "paraphraseHotkey") ?? "cmd+shift+option+p" }
        set { defaults.set(newValue, forKey: "paraphraseHotkey"); objectWillChange.send() }
    }

    var professionalHotkey: String {
        get { defaults.string(forKey: "professionalHotkey") ?? "cmd+shift+option+m" }
        set { defaults.set(newValue, forKey: "professionalHotkey"); objectWillChange.send() }
    }
}
