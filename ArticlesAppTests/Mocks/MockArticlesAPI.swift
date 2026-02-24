//
//  MockArticlesAPI.swift
//  ArticlesAppTests
//
//  Created by Edwinps on 24/2/26.
//

import Testing
import Foundation
@testable import ArticlesApp

final actor MockArticlesAPI: ArticlesAPI {
    struct FetchArticlesCall: Equatable { let page: Int; let perPage: Int }

    private(set) var fetchArticlesCalls: [FetchArticlesCall] = []
    var fetchArticlesResult: [ArticleDTO] = []
    var fetchArticlesError: Error?

    private(set) var fetchArticleDetailCalls: [String] = []
    var fetchArticleDetailResult: ArticleDetailDTO = TestFixtures.makeArticleDetailDTO(
        id: 0, title: "", summary: "", author: "", publishedAt: nil, md: nil, html: nil
    )
    var fetchArticleDetailError: Error?

    func fetchArticles(page: Int, perPage: Int) async throws -> [ArticleDTO] {
        fetchArticlesCalls.append(.init(page: page, perPage: perPage))
        if let fetchArticlesError { throw fetchArticlesError }
        return fetchArticlesResult
    }

    func fetchArticleDetail(id: String) async throws -> ArticleDetailDTO {
        fetchArticleDetailCalls.append(id)
        if let fetchArticleDetailError { throw fetchArticleDetailError }
        return fetchArticleDetailResult
    }
}
