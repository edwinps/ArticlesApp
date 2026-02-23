import Foundation

protocol ArticlesRepository: Sendable {
    func observeArticles(searchText: String?, author: String?) -> AsyncStream<[Article]>
    func observeArticles() -> AsyncStream<[Article]>
    func observeArticle(id: String) -> AsyncStream<Article?>
    func fetchArticles(page: Int, perPage: Int) async throws
    func fetchArticleDetail(id: String) async throws
}
