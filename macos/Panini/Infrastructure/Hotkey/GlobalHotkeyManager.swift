import Carbon
import Foundation

enum GlobalHotkeyAction: UInt32, CaseIterable {
    case palette = 1
    case fix = 2
    case paraphrase = 3
    case professional = 4
}

struct HotkeyBinding: Equatable {
    let action: GlobalHotkeyAction
    let keyCode: UInt32
    let modifiers: UInt32
}

final class GlobalHotkeyManager {
    static let defaultBindings: [HotkeyBinding] = [
        HotkeyBinding(action: .palette, keyCode: UInt32(kVK_ANSI_G), modifiers: UInt32(cmdKey | shiftKey)),
        HotkeyBinding(action: .fix, keyCode: UInt32(kVK_ANSI_G), modifiers: UInt32(cmdKey | shiftKey | optionKey)),
        HotkeyBinding(action: .paraphrase, keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey | shiftKey | optionKey)),
        HotkeyBinding(action: .professional, keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | shiftKey | optionKey))
    ]

    private var handler: ((GlobalHotkeyAction) -> Void)?
    private var activeActionsByID: [UInt32: GlobalHotkeyAction] = [:]
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    func register(bindings: [HotkeyBinding], handler: @escaping (GlobalHotkeyAction) -> Void) {
        self.handler = handler
        installEventHandlerIfNeeded()
        unregisterHotkeys()
        registerHotkeys(bindings)
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event else { return noErr }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, let userData else { return noErr }

            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handleHotKey(id: hotKeyID.id)
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }

    private func registerHotkeys(_ bindings: [HotkeyBinding]) {
        activeActionsByID.removeAll()

        for binding in bindings {
            let hotKeyID = EventHotKeyID(signature: OSType(0x47524149), id: binding.action.rawValue)
            var hotkeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                binding.keyCode,
                binding.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotkeyRef
            )

            guard status == noErr, let hotkeyRef else { continue }
            activeActionsByID[binding.action.rawValue] = binding.action
            hotkeyRefs.append(hotkeyRef)
        }
    }

    private func unregisterHotkeys() {
        for hotkeyRef in hotkeyRefs {
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRefs.removeAll()
        activeActionsByID.removeAll()
    }

    private func handleHotKey(id: UInt32) {
        guard let action = activeActionsByID[id] else { return }
        handler?(action)
    }

    deinit {
        unregisterHotkeys()
    }
}
