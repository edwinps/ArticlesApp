//
//  MockArticlesStore.swift
//  ArticlesAppTests
//
//  Created by Edwinps on 24/2/26.
//

import Testing
import Foundation
@testable import ArticlesApp

final class MockArticlesStore: @unchecked Sendable, ArticlesStore {
    private(set) var observeArticlesCalls: Int = 0
    private(set) var observeArticleCalls: [String] = []

    private(set) var upsertArticlesCalls: [[Article]] = []
    private(set) var upsertDetailCalls: [Article] = []

    func observeArticles(searchText: String?, author: String?) -> AsyncStream<[Article]> {
        observeArticlesCalls += 1
        return AsyncStream { $0.finish() }
    }

    func observeArticles() -> AsyncStream<[Article]> {
        observeArticlesCalls += 1
        return AsyncStream { $0.finish() }
    }

    func observeArticle(id: String) -> AsyncStream<Article?> {
        observeArticleCalls.append(id)
        return AsyncStream { $0.finish() }
    }

    func upsert(articles: [Article]) async throws {
        upsertArticlesCalls.append(articles)
    }

    func upsert(detail: Article) async throws {
        upsertDetailCalls.append(detail)
    }
}
