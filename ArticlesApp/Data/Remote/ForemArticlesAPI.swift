import Foundation

struct ForemArticlesAPI: ArticlesAPI {
    private let baseURLString = "https://dev.to/api/articles"
    private let client: HTTPClient

    init(client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    func fetchArticles(page: Int, perPage: Int) async throws -> [ArticleDTO] {
        var components = URLComponents(string: baseURLString)
        components?.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        return try await client.get(url)
    }

    func fetchArticleDetail(id: String) async throws -> ArticleDetailDTO {
        guard let url = URL(string: "\(baseURLString)/\(id)") else {
            throw NetworkError.invalidURL
        }

        return try await client.get(url)
    }
}
