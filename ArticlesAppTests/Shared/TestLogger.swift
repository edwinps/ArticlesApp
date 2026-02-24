//
//  TestLogger.swift
//  ArticlesAppTests
//
//

import Foundation
import Testing

@testable import ArticlesApp

struct TestLogger: AppLogger, Sendable {
    func debug(_ message: String) {}
    func info(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}
    func error(_ error: Error, message: String) {}
}

