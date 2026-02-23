//
//  ArticlesRepository.swift
//  ArticlesApp
//
//

import Foundation

protocol ArticlesRepository: Sendable {
    func observeArticles() -> AsyncStream<[Article]>
    func observeArticle(id: String) -> AsyncStream<Article?>
    func fetchArticles(forceRefresh: Bool) async throws
    func fetchArticleDetail(id: String) async throws
}
