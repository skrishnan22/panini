import Foundation

protocol UndoManaging {
    func push(previousText: String)
    func popIfValid(now: Date) -> String?
}

final class UndoBuffer: UndoManaging {
    private let ttlSeconds: TimeInterval
    private var entry: (text: String, timestamp: Date)?

    init(ttlSeconds: TimeInterval = 10) {
        self.ttlSeconds = ttlSeconds
    }

    func push(previousText: String) {
        entry = (text: previousText, timestamp: Date())
    }

    func popIfValid(now: Date = Date()) -> String? {
        guard let entry else { return nil }
        defer { self.entry = nil }

        guard now.timeIntervalSince(entry.timestamp) <= ttlSeconds else {
            return nil
        }

        return entry.text
    }
}
