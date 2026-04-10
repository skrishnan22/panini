import Foundation
import os

enum AppLogger {
    static let coordinator = Logger(subsystem: "com.grammarai.macos", category: "coordinator")
    static let api = Logger(subsystem: "com.grammarai.macos", category: "api")
    static let server = Logger(subsystem: "com.grammarai.macos", category: "server")
    static let accessibility = Logger(subsystem: "com.grammarai.macos", category: "accessibility")
}
