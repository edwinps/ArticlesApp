//
//  ArticleDetailViewModelTests.swift
//  ArticlesAppTests
//
//

import Foundation
import Testing

@testable import ArticlesApp

@MainActor
struct ArticleDetailViewModelTests {
    
    @Test
    func start_setsArticleFromCache_andDoesNotAutoRefresh_whenContentPresent() async throws {
        let repo = MockArticlesRepository()
        let sut = ArticleDetailViewModel(articleId: "1", repository: repo, logger: TestLogger())
        
        await sut.send(.start)
        
        try await waitUntil { repo.observeArticleCalls == ["1"] }
        
        let cached = Article(
            id: "1", title: "T", summary: "S", author: "A", publishedAt: .now, content: "FULL"
        )
        repo.articleStream.yield(cached)
        
        try await waitUntil { sut.article?.id == "1" }
        
        #expect(sut.isMissingOffline == false)
        #expect(repo.fetchArticleDetailCalls.isEmpty)
        #expect(sut.state == .idle)
    }
    
    @Test
    func start_autoRefreshesOnce_whenCachedButContentEmpty() async throws {
        let repo = MockArticlesRepository()
        let sut = ArticleDetailViewModel(articleId: "99", repository: repo, logger: TestLogger())
        
        await sut.send(.start)
        try await waitUntil { repo.observeArticleCalls == ["99"] }
        
        let cachedEmpty = Article(
            id: "99", title: "T", summary: "S", author: "A", publishedAt: .now, content: ""
        )
        repo.articleStream.yield(cachedEmpty)
        
        try await waitUntil { sut.article?.id == "99" }
        try await waitUntil { repo.fetchArticleDetailCalls == ["99"] }
        try await waitUntil { sut.state == .idle }
        
        repo.articleStream.yield(cachedEmpty)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(repo.fetchArticleDetailCalls == ["99"])
    }
    
    @Test
    func refresh_nonOfflineError_setsErrorOnlyWhenNoCache() async throws {
        let repo = MockArticlesRepository()
        let sut = ArticleDetailViewModel(articleId: "8", repository: repo, logger: TestLogger())
        
        await sut.send(.start)
        try await waitUntil { repo.observeArticleCalls == ["8"] }
        
        repo.articleStream.yield(nil)
        try await waitUntil { sut.article == nil && sut.isMissingOffline == true }
        
        repo.fetchArticleDetailError = NetworkError.httpStatus(500, nil)
        
        await sut.send(.refresh)
        try await waitUntil { repo.fetchArticleDetailCalls == ["8"] }
        
        let isErrorState: Bool = {
            if case .error = sut.state { return true }
            return false
        }()
        #expect(isErrorState)
    }
    
    @Test
    func refresh_nonOfflineError_doesNotOverwriteContentWithError_whenCacheExists() async throws {
        let repo = MockArticlesRepository()
        let sut = ArticleDetailViewModel(articleId: "10", repository: repo, logger: TestLogger())
        
        await sut.send(.start)
        try await waitUntil { repo.observeArticleCalls == ["10"] }
        
        let cached = Article(
            id: "10",
            title: "T",
            summary: "S",
            author: "A",
            publishedAt: .now,
            content: "CACHED CONTENT"
        )
        
        repo.articleStream.yield(cached)
        try await waitUntil { sut.article?.id == "10" }
        
        repo.fetchArticleDetailError = NetworkError.httpStatus(503, nil)
        
        await sut.send(.refresh)
        try await waitUntil { repo.fetchArticleDetailCalls == ["10"] }
        try await waitUntil { sut.state == .idle }
        
        #expect(sut.article?.content == "CACHED CONTENT")
    }
    
    @Test
    func stop_cancelsObservation_andResetsStartFlag() async throws {
        let repo = MockArticlesRepository()
        let sut = ArticleDetailViewModel(articleId: "1", repository: repo, logger: TestLogger())
        
        await sut.send(.start)
        try await waitUntil { repo.observeArticleCalls == ["1"] }
        
        await sut.send(.stop)
        
        await sut.send(.start)
        try await waitUntil { repo.observeArticleCalls == ["1", "1"] }
        
        #expect(repo.observeArticleCalls == ["1", "1"])
    }
}
