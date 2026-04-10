import ApplicationServices
import Foundation

struct AXElementCapabilities: Equatable {
    let supportedAttributes: Set<String>
    let supportedParameterizedAttributes: Set<String>
    let settableAttributes: Set<String>

    static func snapshot(from element: AXInspectableTextElement) -> AXElementCapabilities {
        let attributeNames = Set(element.attributeNames())
        let parameterizedNames = Set(element.parameterizedAttributeNames())
        let settable = Set(attributeNames.filter { element.isAttributeSettable($0) })

        return AXElementCapabilities(
            supportedAttributes: attributeNames,
            supportedParameterizedAttributes: parameterizedNames,
            settableAttributes: settable
        )
    }
}

protocol AXInspectableTextElement: AXTextElement {
    func attributeNames() -> [String]
    func parameterizedAttributeNames() -> [String]
    func isAttributeSettable(_ attribute: String) -> Bool
    func parameterizedValue(for attribute: String, parameter: AnyObject) -> AnyObject?
}

extension AXTextElementRef: AXInspectableTextElement {
    func attributeNames() -> [String] {
        var names: CFArray?
        let error = AXUIElementCopyAttributeNames(raw, &names)
        guard error == .success else { return [] }
        return names as? [String] ?? []
    }

    func parameterizedAttributeNames() -> [String] {
        var names: CFArray?
        let error = AXUIElementCopyParameterizedAttributeNames(raw, &names)
        guard error == .success else { return [] }
        return names as? [String] ?? []
    }

    func isAttributeSettable(_ attribute: String) -> Bool {
        var isSettable: DarwinBoolean = false
        let error = AXUIElementIsAttributeSettable(raw, attribute as CFString, &isSettable)
        return error == .success && isSettable.boolValue
    }

    func parameterizedValue(for attribute: String, parameter: AnyObject) -> AnyObject? {
        var value: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(raw, attribute as CFString, parameter, &value)
        guard error == .success else { return nil }
        return value
    }
}

extension AXTextWritableElementRef: AXInspectableTextElement {
    func attributeNames() -> [String] {
        var names: CFArray?
        let error = AXUIElementCopyAttributeNames(raw, &names)
        guard error == .success else { return [] }
        return names as? [String] ?? []
    }

    func parameterizedAttributeNames() -> [String] {
        var names: CFArray?
        let error = AXUIElementCopyParameterizedAttributeNames(raw, &names)
        guard error == .success else { return [] }
        return names as? [String] ?? []
    }

    func isAttributeSettable(_ attribute: String) -> Bool {
        var isSettable: DarwinBoolean = false
        let error = AXUIElementIsAttributeSettable(raw, attribute as CFString, &isSettable)
        return error == .success && isSettable.boolValue
    }

    func parameterizedValue(for attribute: String, parameter: AnyObject) -> AnyObject? {
        var value: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(raw, attribute as CFString, parameter, &value)
        guard error == .success else { return nil }
        return value
    }
}
