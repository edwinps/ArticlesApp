//
//  MockArticlesRepository.swift
//  ArticlesAppTests
//
//

import Testing
import Foundation
@testable import ArticlesApp

final class AsyncStreamController<Element>: @unchecked Sendable {
    private var continuation: AsyncStream<Element>.Continuation?
    private var buffer: [Element] = []
    private var isFinished = false

    func makeStream() -> AsyncStream<Element> {
        AsyncStream { continuation in
            self.continuation = continuation

            if !buffer.isEmpty {
                buffer.forEach { continuation.yield($0) }
                buffer.removeAll()
            }

            if isFinished {
                continuation.finish()
            }
        }
    }

    func yield(_ value: Element) {
        if let continuation {
            continuation.yield(value)
        } else {
            buffer.append(value)
        }
    }

    func finish() {
        if let continuation {
            continuation.finish()
        } else {
            isFinished = true
        }
    }
}

final class MockArticlesRepository: @unchecked Sendable, ArticlesRepository {
    // MARK: - Streams (controlled)
    let articlesStream = AsyncStreamController<[Article]>()
    let articleStream = AsyncStreamController<Article?>()

    func observeArticles() -> AsyncStream<[Article]> {
        observeArticlesCalls += 1
        return articlesStream.makeStream()
    }

    func observeArticle(id: String) -> AsyncStream<Article?> {
        observeArticleCalls.append(id)
        return articleStream.makeStream()
    }

    // MARK: - Fetch calls tracking
    private(set) var observeArticlesCalls: Int = 0
    private(set) var observeArticleCalls: [String] = []

    private(set) var fetchArticlesCalls: [(page: Int, perPage: Int)] = []
    var fetchArticlesResultCount: Int = 0
    var fetchArticlesError: Error?

    private(set) var fetchArticleDetailCalls: [String] = []
    var fetchArticleDetailError: Error?

    func fetchArticles(page: Int, perPage: Int) async throws -> Int {
        fetchArticlesCalls.append((page, perPage))
        if let fetchArticlesError { throw fetchArticlesError }
        return fetchArticlesResultCount
    }

    func fetchArticleDetail(id: String) async throws {
        fetchArticleDetailCalls.append(id)
        if let fetchArticleDetailError { throw fetchArticleDetailError }
    }
}
