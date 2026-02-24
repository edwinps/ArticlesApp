//
//  ArticlesListViewModelTests.swift
//  ArticlesAppTests
//
//

import Foundation
import Testing
@testable import ArticlesApp
@MainActor
struct ArticlesListViewModelTests {

    @Test
    func start_subscribesToArticlesStream_andInitialFetchIsTriggered() async throws {
        let repo = MockArticlesRepository()
        repo.fetchArticlesResultCount = 20
        let sut = ArticlesListViewModel(repository: repo, logger: TestLogger())

        await sut.send(.start)

        try await waitUntil { repo.observeArticlesCalls == 1 }
        try await waitUntil { repo.fetchArticlesCalls.count == 1 }

        #expect(repo.fetchArticlesCalls.first?.page == 1)
        #expect(repo.fetchArticlesCalls.first?.perPage == 20)
    }

    @Test
    func streamEmits_articles_updatesState_loaded_andAvailableAuthors() async throws {
        let repo = MockArticlesRepository()
        let sut = ArticlesListViewModel(repository: repo, logger: TestLogger())

        await sut.send(.start)
        try await waitUntil { repo.observeArticlesCalls == 1 }

        let a1 = Article(id: "1", title: "Swift", summary: "S1", author: "Edwin Jose", publishedAt: .now, content: "")
        let a2 = Article(id: "2", title: "iOS", summary: "S2", author: "Ana", publishedAt: .now, content: "")
        repo.articlesStream.yield([a1, a2])

        try await waitUntil {
            if case .loaded(let items) = sut.state {
                return items.count == 2
            }
            return false
        }

        #expect(sut.availableAuthors == ["Ana", "Edwin Jose"])
    }

    @Test
    func authorFilter_filtersInMemory() async throws {
        let repo = MockArticlesRepository()
        let sut = ArticlesListViewModel(repository: repo, logger: TestLogger())

        await sut.send(.start)
        try await waitUntil { repo.observeArticlesCalls == 1 }

        let a1 = Article(id: "1", title: "Swift", summary: "S1", author: "Edwin Jose", publishedAt: .now, content: "")
        let a2 = Article(id: "2", title: "iOS", summary: "S2", author: "Ana", publishedAt: .now, content: "")
        repo.articlesStream.yield([a1, a2])

        try await waitUntil {
            if case .loaded(let items) = sut.state { return items.count == 2 }
            return false
        }

        sut.authorFilter = "Edwin Jose"

        try await waitUntil {
            if case .loaded(let items) = sut.state { return items.map(\.id) == ["1"] }
            return false
        }
    }

    @Test
    func searchQuery_filtersAfterDebounce() async throws {
        let repo = MockArticlesRepository()
        let sut = ArticlesListViewModel(repository: repo, logger: TestLogger())

        await sut.send(.start)
        try await waitUntil { repo.observeArticlesCalls == 1 }

        let a1 = Article(id: "1", title: "Swift Concurrency", summary: "S1", author: "Edwin", publishedAt: .now, content: "")
        let a2 = Article(id: "2", title: "Realm", summary: "S2", author: "Ana", publishedAt: .now, content: "")
        repo.articlesStream.yield([a1, a2])

        try await waitUntil {
            if case .loaded(let items) = sut.state { return items.count == 2 }
            return false
        }

        sut.searchQuery = "realm"

        try await waitUntil {
            if case .loaded(let items) = sut.state { return items.map(\.id) == ["2"] }
            return false
        }
    }

    @Test
    func loadMore_isIgnored_whenSearching() async throws {
        let repo = MockArticlesRepository()
        repo.fetchArticlesResultCount = 20
        let sut = ArticlesListViewModel(repository: repo, logger: TestLogger())

        await sut.send(.start)
        try await waitUntil { repo.fetchArticlesCalls.count == 1 }

        sut.searchQuery = "x"
        try await Task.sleep(nanoseconds: 300_000_000)

        await sut.send(.loadMore)

        #expect(repo.fetchArticlesCalls.count == 1)
    }

    @Test
    func loadMore_fetchesNextPage_whenNotSearching_andHasMore() async throws {
        let repo = MockArticlesRepository()
        repo.fetchArticlesResultCount = 20
        let sut = ArticlesListViewModel(repository: repo, logger: TestLogger())

        await sut.send(.start)
        try await waitUntil { repo.fetchArticlesCalls.count == 1 }

        await sut.send(.loadMore)
        try await waitUntil { repo.fetchArticlesCalls.count == 2 }

        #expect(repo.fetchArticlesCalls[0].page == 1)
        #expect(repo.fetchArticlesCalls[1].page == 2)
    }
    
    @Test
    func fetchOffline_withEmptyCache_transitionsToEmpty() async throws {
        let repo = MockArticlesRepository()
        repo.fetchArticlesError = NetworkError.offline
        let sut = ArticlesListViewModel(repository: repo, logger: TestLogger())

        await sut.send(.start)

        try await waitUntil { repo.fetchArticlesCalls.count == 1 }
        try await waitUntil { sut.state == .empty }
    }

    @Test
    func stop_allowsRestart_andSubscribesAgain() async throws {
        let repo = MockArticlesRepository()
        let sut = ArticlesListViewModel(repository: repo, logger: TestLogger())

        await sut.send(.start)
        try await waitUntil { repo.observeArticlesCalls == 1 }

        await sut.send(.stop)
        await sut.send(.start)

        try await waitUntil { repo.observeArticlesCalls == 2 }
        #expect(repo.observeArticlesCalls == 2)
    }
}

