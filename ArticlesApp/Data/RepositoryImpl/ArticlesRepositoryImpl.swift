//
//  ArticlesRepositoryImpl.swift
//  ArticlesApp
//
//

import Foundation

final class ArticlesRepositoryImpl: ArticlesRepository {
    private let api: ArticlesAPI
    private let store: ArticlesStore
    private let perPageDefault = 20

    init(api: ArticlesAPI, store: ArticlesStore) {
        self.api = api
        self.store = store
    }

    func observeArticles(searchText: String?, author: String?) -> AsyncStream<[Article]> {
        store.observeArticles(searchText: searchText, author: author)
    }

    func observeArticles() -> AsyncStream<[Article]> {
        store.observeArticles()
    }

    func observeArticle(id: String) -> AsyncStream<Article?> {
        store.observeArticle(id: id)
    }

    func fetchArticles(page: Int, perPage: Int) async throws {
        let dtos = try await api.fetchArticles(page: page, perPage: perPage)

        let articles = dtos.map { dto in
            Article(
                id: String(dto.id),
                title: dto.title,
                summary: dto.summary,
                author: dto.authorName,
                publishedAt: dto.publishedAt ?? .distantPast,
                content: Self.preferredContentString(markdown: dto.bodyMarkdown, html: dto.bodyHTML)
            )
        }

        try await store.upsert(articles: articles)
    }

    func fetchArticleDetail(id: String) async throws {
        let dto = try await api.fetchArticleDetail(id: id)

        let article = Article(
            id: String(dto.id),
            title: dto.title,
            summary: dto.summary,
            author: dto.authorName,
            publishedAt: dto.publishedAt ?? .distantPast,
            content: Self.preferredContentString(markdown: dto.bodyMarkdown, html: dto.bodyHTML)
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
