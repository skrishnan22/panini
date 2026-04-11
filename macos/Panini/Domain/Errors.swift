import Foundation

public enum PaniniError: LocalizedError {
    case selectionUnavailable
    case writeFailed
    case accessibilityPermissionMissing
    case serverUnavailable
    case backendRequestFailed(String)
    case keychainError(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .selectionUnavailable:
            return "No selected text is available. Keep the text field focused and use the hotkey (Cmd+Shift+G) instead of clicking the menu while testing selection capture."
        case .writeFailed:
            return "Unable to write corrected text into the focused field."
        case .accessibilityPermissionMissing:
            return "Accessibility permission is required for direct text replacement."
        case .serverUnavailable:
            return "Local Panini server is unavailable."
        case let .backendRequestFailed(message):
            return message
        case let .keychainError(status):
            return "Keychain operation failed with status: \(status)."
        }
    }
}
