import Foundation

protocol ArticlesRepository: Sendable {
    func observeArticles() -> AsyncStream<[Article]>
    func observeArticle(id: String) -> AsyncStream<Article?>
    func fetchArticles(page: Int, perPage: Int) async throws -> Int
    func fetchArticleDetail(id: String) async throws
}
