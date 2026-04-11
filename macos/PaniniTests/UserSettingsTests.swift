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
        XCTAssertEqual(settings.selectedModelID, "gemma-4-e4b")
    }

    func testSetSelectedModelID() {
        settings.selectedModelID = "qwen-2.5-3b"
        XCTAssertEqual(settings.selectedModelID, "qwen-2.5-3b")
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
