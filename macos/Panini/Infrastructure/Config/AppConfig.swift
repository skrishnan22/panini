import Foundation

public struct AppConfig: Sendable {
    public let undoWindowSeconds: TimeInterval
    public let defaultPreset: String
    public let defaultMode: CorrectionMode

    public init(
        undoWindowSeconds: TimeInterval = 10,
        defaultPreset: String = "fix",
        defaultMode: CorrectionMode = .review
    ) {
        self.undoWindowSeconds = undoWindowSeconds
        self.defaultPreset = defaultPreset
        self.defaultMode = defaultMode
    }
}
