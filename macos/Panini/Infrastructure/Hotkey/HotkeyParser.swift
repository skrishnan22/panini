import Carbon
import Foundation

enum HotkeyParser {
    static func parseBindings(
        palette: String,
        fix: String,
        paraphrase: String,
        professional: String
    ) -> [HotkeyBinding] {
        var bindings: [HotkeyBinding] = []
        if let b = parse(palette, action: .palette) { bindings.append(b) }
        if let b = parse(fix, action: .fix) { bindings.append(b) }
        if let b = parse(paraphrase, action: .paraphrase) { bindings.append(b) }
        if let b = parse(professional, action: .professional) { bindings.append(b) }
        return bindings
    }

    private static func parse(_ combo: String, action: GlobalHotkeyAction) -> HotkeyBinding? {
        let parts = combo.lowercased().split(separator: "+").map(String.init)
        var modifiers: UInt32 = 0
        var keyChar: String?

        for part in parts {
            switch part {
            case "cmd": modifiers |= UInt32(cmdKey)
            case "shift": modifiers |= UInt32(shiftKey)
            case "option": modifiers |= UInt32(optionKey)
            case "ctrl": modifiers |= UInt32(controlKey)
            default: keyChar = part
            }
        }

        guard let char = keyChar, let keyCode = keyCodeForCharacter(char) else { return nil }
        return HotkeyBinding(action: action, keyCode: keyCode, modifiers: modifiers)
    }

    private static func keyCodeForCharacter(_ char: String) -> UInt32? {
        let map: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            ";": kVK_ANSI_Semicolon,
        ]
        guard let code = map[char.lowercased()] else { return nil }
        return UInt32(code)
    }
}
