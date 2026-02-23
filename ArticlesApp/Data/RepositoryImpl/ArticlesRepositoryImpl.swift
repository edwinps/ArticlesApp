//
//  ArticlesRepositoryImpl.swift
//  ArticlesApp
//
//

import Foundation

final class ArticlesRepositoryImpl: ArticlesRepository, @unchecked Sendable {
    private let api: ArticlesAPI
    private let store: ArticlesStore

    private let perPage = 20
    private var currentPage = 1
    private var hasMore = true

    init(api: ArticlesAPI, store: ArticlesStore) {
        self.api = api
        self.store = store
    }

    func observeArticles() -> AsyncStream<[Article]> {
        store.observeArticles()
    }

    func observeArticle(id: String) -> AsyncStream<Article?> {
        store.observeArticle(id: id)
    }

    func fetchArticles(forceRefresh: Bool) async throws {
        if forceRefresh {
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }

        let pageToFetch = currentPage
        let dtos = try await api.fetchArticles(page: pageToFetch, perPage: perPage)

        if dtos.isEmpty {
            hasMore = false
            return
        }

        let articles = dtos.map { dto in
            Article(
                id: String(dto.id),
                title: dto.title,
                summary: dto.summary,
                author: dto.authorName,
                publishedAt: dto.publishedAt ?? Date(),
                content: Self.preferredContentString(markdown: dto.bodyMarkdown, html: dto.bodyHTML)
            )
        }

        try await store.upsert(articles: articles)

        if dtos.count < perPage {
            hasMore = false
        } else {
            currentPage += 1
        }
    }

    func fetchArticleDetail(id: String) async throws {
        let dto = try await api.fetchArticleDetail(id: id)

        let content = Self.preferredContentString(markdown: dto.bodyMarkdown, html: dto.bodyHTML)

        let article = Article(
            id: String(dto.id),
            title: dto.title,
            summary: dto.summary,
            author: dto.authorName,
            publishedAt: dto.publishedAt ?? Date(),
            content: content
        )

        try await store.upsert(detail: article)
    }
}

private extension ArticlesRepositoryImpl {
    static func preferredContentString(markdown: String?, html: String?) -> String {
        if let md = markdown, !md.isEmpty { return md }
        if let html = html, !html.isEmpty { return html }
        return ""
    }
}

