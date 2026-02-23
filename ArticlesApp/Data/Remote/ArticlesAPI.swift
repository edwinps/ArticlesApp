//
//  ArticlesAPI.swift
//  ArticlesApp
//
//

import Foundation

protocol ArticlesAPI: Sendable {
    func fetchArticles(page: Int, perPage: Int) async throws -> [ArticleDTO]
    func fetchArticleDetail(id: String) async throws -> ArticleDetailDTO
}
