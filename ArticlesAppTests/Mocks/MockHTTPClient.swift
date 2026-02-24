//
//  MockHTTPClient.swift
//  ArticlesAppTests
//
//  Created by Edwinps on 24/2/26.
//

import Foundation
import Testing
@testable import ArticlesApp

final class MockHTTPClient: @unchecked Sendable, HTTPClientProtocol {
    private(set) var requestedURLs: [URL] = []
    var stubError: Error?
    var stub: ((URL) throws -> Any)?

    func get<T: Decodable>(_ url: URL) async throws -> T {
        requestedURLs.append(url)

        if let stubError { throw stubError }
        guard let stub else { fatalError("Missing stub") }

        let value = try stub(url)
        guard let typed = value as? T else {
            fatalError("Stub returned \(type(of: value)) but expected \(T.self)")
        }
        return typed
    }
}
