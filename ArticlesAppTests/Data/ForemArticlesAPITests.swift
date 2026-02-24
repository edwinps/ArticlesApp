//
//  ForemArticlesAPITests.swift
//  ArticlesAppTests
//
//  Created by Edwinps on 24/2/26.
//

import Foundation
import Testing
@testable import ArticlesApp

struct ForemArticlesAPITests {

    @Test
    func fetchArticles_buildsURLWithQueryItems_andCallsClient() async throws {
        let client = MockHTTPClient()
        let sut = ForemArticlesAPI(client: client)

        let expected: [ArticleDTO] = []
        client.stub = { (url: URL) in expected }

        let result = try await sut.fetchArticles(page: 2, perPage: 50)

        #expect(result.count == expected.count)
        #expect(client.requestedURLs.count == 1)

        let url = try #require(client.requestedURLs.first)
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(comps.scheme == "https")
        #expect(comps.host == "dev.to")
        #expect(comps.path == "/api/articles")

        let items = comps.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "page", value: "2")))
        #expect(items.contains(URLQueryItem(name: "per_page", value: "50")))
    }

    @Test
    func fetchArticleDetail_buildsDetailURL_andCallsClient() async throws {
        let client = MockHTTPClient()
        let sut = ForemArticlesAPI(client: client)

        let expected = makeArticleDetailDTO(id: 123)
        client.stub = { (url: URL) in expected }

        let result = try await sut.fetchArticleDetail(id: "123")

        #expect(result.id == expected.id)
        #expect(client.requestedURLs.count == 1)

        let url = try #require(client.requestedURLs.first)
        #expect(url.absoluteString == "https://dev.to/api/articles/123")
    }

    @Test
    func fetchArticles_whenClientThrows_propagatesError() async throws {
        let client = MockHTTPClient()
        let sut = ForemArticlesAPI(client: client)

        client.stubError = NetworkError.offline

        await #expect(throws: NetworkError.offline) {
            _ = try await sut.fetchArticles(page: 1, perPage: 20)
        }
    }

    @Test
    func fetchArticleDetail_whenClientThrows_propagatesError() async throws {
        let client = MockHTTPClient()
        let sut = ForemArticlesAPI(client: client)

        client.stubError = NetworkError.httpStatus(500, nil)

        await #expect(throws: NetworkError.httpStatus(500, nil)) {
            _ = try await sut.fetchArticleDetail(id: "999")
        }
    }
}
private func makeArticleDetailDTO(id: Int) -> ArticleDetailDTO {
    let json = """
    {
      "id": \(id),
      "title": "Title",
      "description": "Desc",
      "user": { "name": "Author" },
      "published_at": null,
      "body_markdown": "",
      "body_html": ""
    }
    """
    let data = Data(json.utf8)
    return (try? JSONDecoder().decode(ArticleDetailDTO.self, from: data)) ?? {
        fatalError("Could not decode ArticleDetailDTO fixture. Adjust JSON keys to match your DTO CodingKeys.")
    }()
}
