//
//  ArticlesRepositoryImplTests.swift
//  ArticlesAppTests
//
//  Created by Edwinps on 24/2/26.
//

import Foundation
import Testing
@testable import ArticlesApp

struct ArticlesRepositoryImplTests {

    @Test
    func observeArticles_delegatesToStore() async throws {
        let api = MockArticlesAPI()
        let store = MockArticlesStore()
        let sut = ArticlesRepositoryImpl(api: api, store: store)

        _ = sut.observeArticles()

        #expect(store.observeArticlesCalls == 1)
    }

    @Test
    func observeArticle_delegatesToStoreWithId() async throws {
        let api = MockArticlesAPI()
        let store = MockArticlesStore()
        let sut = ArticlesRepositoryImpl(api: api, store: store)

        _ = sut.observeArticle(id: "abc")

        #expect(store.observeArticleCalls == ["abc"])
    }

    @Test
    func fetchArticles_mapsAndUpserts_andReturnsCount() async throws {
        let api = MockArticlesAPI()
        let store = MockArticlesStore()
        let sut = ArticlesRepositoryImpl(api: api, store: store)

        api.fetchArticlesResult = [
            makeArticleDTO(id: 1, title: "T1", summary: "S1", author: "A1", publishedAt: Date(timeIntervalSince1970: 1), md: "md", html: "<p>h</p>"),
            makeArticleDTO(id: 2, title: "T2", summary: "S2", author: "A2", publishedAt: nil, md: nil, html: "<p>only html</p>"),
            makeArticleDTO(id: 3, title: "T3", summary: "S3", author: "A3", publishedAt: nil, md: "", html: "")
        ]

        let count = try await sut.fetchArticles(page: 3, perPage: 20)

        #expect(api.fetchArticlesCalls.count == 1)
        #expect(api.fetchArticlesCalls.first?.page == 3)
        #expect(api.fetchArticlesCalls.first?.perPage == 20)

        #expect(count == 3)
        #expect(store.upsertArticlesCalls.count == 1)

        let upserted = try #require(store.upsertArticlesCalls.first)
        #expect(upserted.count == 3)

        #expect(upserted[0].id == "1")
        #expect(upserted[0].title == "T1")
        #expect(upserted[0].author == "A1")
        #expect(upserted[0].publishedAt == Date(timeIntervalSince1970: 1))
        #expect(upserted[0].content == "md")

        #expect(upserted[1].id == "2")
        #expect(upserted[1].content == "<p>only html</p>")
        #expect(upserted[1].publishedAt == .distantPast)

        #expect(upserted[2].id == "3")
        #expect(upserted[2].content == "")
        #expect(upserted[2].publishedAt == .distantPast)
    }

    @Test
    func fetchArticles_whenAPIThrows_doesNotUpsert() async throws {
        let api = MockArticlesAPI()
        let store = MockArticlesStore()
        let sut = ArticlesRepositoryImpl(api: api, store: store)

        api.fetchArticlesError = NetworkError.offline

        await #expect(throws: NetworkError.offline) {
            _ = try await sut.fetchArticles(page: 1, perPage: 20)
        }

        #expect(store.upsertArticlesCalls.isEmpty)
    }

    @Test
    func fetchArticleDetail_mapsAndUpsertsDetail() async throws {
        let api = MockArticlesAPI()
        let store = MockArticlesStore()
        let sut = ArticlesRepositoryImpl(api: api, store: store)

        api.fetchArticleDetailResult = makeArticleDetailDTO(id: 77, title: "DT", summary: "DS", author: "DA", publishedAt: nil, md: nil, html: "<p>detail</p>")

        try await sut.fetchArticleDetail(id: "77")

        #expect(api.fetchArticleDetailCalls == ["77"])
        #expect(store.upsertDetailCalls.count == 1)

        let article = try #require(store.upsertDetailCalls.first)
        #expect(article.id == "77")
        #expect(article.title == "DT")
        #expect(article.summary == "DS")
        #expect(article.author == "DA")
        #expect(article.publishedAt == .distantPast)
        #expect(article.content == "<p>detail</p>")
    }

    @Test
    func fetchArticleDetail_whenAPIThrows_doesNotUpsert() async throws {
        let api = MockArticlesAPI()
        let store = MockArticlesStore()
        let sut = ArticlesRepositoryImpl(api: api, store: store)

        api.fetchArticleDetailError = NetworkError.httpStatus(500, nil)

        await #expect(throws: NetworkError.httpStatus(500, nil)) {
            try await sut.fetchArticleDetail(id: "123")
        }

        #expect(store.upsertDetailCalls.isEmpty)
    }
}

private func makeArticleDTO(
    id: Int,
    title: String,
    summary: String,
    author: String,
    publishedAt: Date?,
    md: String?,
    html: String?
) -> ArticleDTO {
    let json = """
    {
      "id": \(id),
      "title": "\(escapeJSON(title))",
      "description": "\(escapeJSON(summary))",
      "user": { "name": "\(escapeJSON(author))" },
      "published_at": \(publishedAt == nil ? "null" : "\"\(iso8601(publishedAt!))\""),
      "body_markdown": \(md == nil ? "null" : "\"\(escapeJSON(md!))\""),
      "body_html": \(html == nil ? "null" : "\"\(escapeJSON(html!))\"")
    }
    """
    let data = Data(json.utf8)
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArticleDTO.self, from: data)
    } catch {
        fatalError("Adjust fixture keys to match ArticleDTO CodingKeys. Error: \(error)")
    }
}

private func makeArticleDetailDTO(
    id: Int,
    title: String,
    summary: String,
    author: String,
    publishedAt: Date?,
    md: String?,
    html: String?
) -> ArticleDetailDTO {
    let json = """
    {
      "id": \(id),
      "title": "\(escapeJSON(title))",
      "description": "\(escapeJSON(summary))",
      "user": { "name": "\(escapeJSON(author))" },
      "published_at": \(publishedAt == nil ? "null" : "\"\(iso8601(publishedAt!))\""),
      "body_markdown": \(md == nil ? "null" : "\"\(escapeJSON(md!))\""),
      "body_html": \(html == nil ? "null" : "\"\(escapeJSON(html!))\"")
    }
    """
    let data = Data(json.utf8)
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArticleDetailDTO.self, from: data)
    } catch {
        fatalError("Adjust fixture keys to match ArticleDetailDTO CodingKeys. Error: \(error)")
    }
}

private func iso8601(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    return f.string(from: date)
}

private func escapeJSON(_ s: String) -> String {
    s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\t", with: "\\t")
}
