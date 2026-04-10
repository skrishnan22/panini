import ApplicationServices
import Foundation
@testable import GrammarAI

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            fatalError("MockURLProtocol.handler not set")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

func makeMockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

func makeAXRangeValue(_ range: CFRange) -> AXValue {
    var mutableRange = range
    return AXValueCreate(.cfRange, &mutableRange)!
}

final class MockAXCapabilityElement: AXTextWritableElement {
    var attributes: [String: AnyObject]
    var attributeNamesList: [String]
    var parameterizedAttributeNamesList: [String]
    var settableAttributes: Set<String>
    var parameterizedValues: [String: AnyObject]
    var nextWriteError: AXError
    private(set) var lastSetAttribute: String?
    private(set) var lastSetStringValue: String?

    init(
        attributes: [String: AnyObject] = [:],
        attributeNames: [String] = [],
        parameterizedAttributeNames: [String] = [],
        settableAttributes: [String] = [],
        parameterizedValues: [String: AnyObject] = [:],
        nextWriteError: AXError = .success
    ) {
        self.attributes = attributes
        self.attributeNamesList = attributeNames
        self.parameterizedAttributeNamesList = parameterizedAttributeNames
        self.settableAttributes = Set(settableAttributes)
        self.parameterizedValues = parameterizedValues
        self.nextWriteError = nextWriteError
    }

    func value(for attribute: String) -> AnyObject? {
        attributes[attribute]
    }

    func attributeNames() -> [String] {
        attributeNamesList
    }

    func parameterizedAttributeNames() -> [String] {
        parameterizedAttributeNamesList
    }

    func isAttributeSettable(_ attribute: String) -> Bool {
        settableAttributes.contains(attribute)
    }

    func parameterizedValue(for attribute: String, parameter: AnyObject) -> AnyObject? {
        parameterizedValues[attribute]
    }

    func setValue(_ value: AnyObject, for attribute: String) -> AXError {
        lastSetAttribute = attribute
        lastSetStringValue = value as? String
        attributes[attribute] = value
        return nextWriteError
    }
}
