import Foundation

public enum PaniniError: LocalizedError {
    case selectionUnavailable
    case writeFailed
    case accessibilityPermissionMissing
    case backendRequestFailed(String)
    case keychainError(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .selectionUnavailable:
            return "No selected text is available. Keep the source text focused and use a direct action hotkey instead of clicking the menu."
        case .writeFailed:
            return "Unable to write corrected text into the focused field."
        case .accessibilityPermissionMissing:
            return "Accessibility permission is required for direct text replacement."
        case let .backendRequestFailed(message):
            return message
        case let .keychainError(status):
            return "Keychain operation failed with status: \(status)."
        }
    }
}
