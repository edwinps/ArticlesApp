import Foundation
import os

public protocol AppLogger: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func error(_ error: Error, message: String)
}

public struct DefaultLogger: AppLogger {
    public static let shared = DefaultLogger()

    private let logger: os.Logger

    public init(subsystem: String = (Bundle.main.bundleIdentifier ?? "ArticlesApp"),
                category: String = "App") {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    public func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    public func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    public func error(_ error: Error, message: String) {
        logger.error("\(message, privacy: .public) error=\(String(describing: error), privacy: .public)")
    }
}
