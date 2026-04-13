import XCTest
@testable import GrammarAI

final class UserSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: UserSettings!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "UserSettingsTests")!
        defaults.removePersistentDomain(forName: "UserSettingsTests")
        settings = UserSettings(defaults: defaults)
    }

    func testDefaultPresetIsFix() {
        XCTAssertEqual(settings.defaultPreset, "fix")
    }

    func testSetDefaultPreset() {
        settings.defaultPreset = "improve"
        XCTAssertEqual(settings.defaultPreset, "improve")
        XCTAssertEqual(defaults.string(forKey: "defaultPreset"), "improve")
    }

    func testDefaultBackendIsLocal() {
        XCTAssertEqual(settings.backendChoice, .local)
    }

    func testSetBackendChoice() {
        settings.backendChoice = .cloud
        XCTAssertEqual(settings.backendChoice, .cloud)
    }

    func testDefaultModelID() {
        XCTAssertEqual(settings.selectedModelID, LocalModelCatalog.defaultModelID)
    }

    func testSetSelectedModelID() {
        settings.selectedModelID = "mlx-community/Qwen3-1.7B-4bit"
        XCTAssertEqual(settings.selectedModelID, "mlx-community/Qwen3-1.7B-4bit")
    }

    func testMigratesLegacySelectedModelID() {
        defaults.set("qwen-2.5-3b", forKey: "selectedModelID")

        XCTAssertEqual(settings.selectedModelID, LocalModelCatalog.defaultModelID)
        XCTAssertEqual(defaults.string(forKey: "selectedModelID"), LocalModelCatalog.defaultModelID)
    }

    func testDefaultLaunchAtLogin() {
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testHotkeyDefaults() {
        XCTAssertEqual(settings.paletteHotkey, "cmd+shift+g")
        XCTAssertEqual(settings.fixHotkey, "cmd+shift+option+g")
        XCTAssertEqual(settings.paraphraseHotkey, "cmd+shift+option+p")
        XCTAssertEqual(settings.professionalHotkey, "cmd+shift+option+m")
    }

    func testSetHotkey() {
        settings.paletteHotkey = "cmd+shift+r"
        XCTAssertEqual(settings.paletteHotkey, "cmd+shift+r")
    }
}
