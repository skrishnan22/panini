import ApplicationServices
import Foundation

enum AXReadStrategy: Equatable {
    case selectedTextAttribute
    case selectedTextRange
    case clipboardFallback
}

enum AXWriteStrategy: Equatable {
    case selectedTextAttribute
    case valueAndSelectedTextRange
    case clipboardFallback
}

struct TextEditingSession {
    let targetProcessIdentifier: pid_t?
    let element: AXInspectableTextElement
    let capabilities: AXElementCapabilities
    let selectedText: String
    let selectedRange: CFRange?
    let fullValue: String?
    let readStrategy: AXReadStrategy
    let writeStrategy: AXWriteStrategy
}
