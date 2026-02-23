//
//  ArticleDetailDTO.swift
//  ArticlesApp
//
//

import Foundation

struct ArticleDetailDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let summary: String
    let publishedAt: Date?
    let authorName: String
    let bodyMarkdown: String?
    let bodyHTML: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary = "description"
        case publishedAt = "published_at"
        case user
        case bodyMarkdown = "body_markdown"
        case bodyHTML = "body_html"
    }

    private struct UserDTO: Decodable, Sendable {
        let name: String
        enum CodingKeys: String, CodingKey { case name }
    }

    init(
        id: Int = 0,
        title: String = "",
        summary: String = "",
        publishedAt: Date? = nil,
        authorName: String = "",
        bodyMarkdown: String? = nil,
        bodyHTML: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.publishedAt = publishedAt
        self.authorName = authorName
        self.bodyMarkdown = bodyMarkdown
        self.bodyHTML = bodyHTML
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = (try? container.decode(Int.self, forKey: .id)) ?? 0
        self.title = (try? container.decode(String.self, forKey: .title)) ?? ""
        self.summary = (try? container.decode(String.self, forKey: .summary)) ?? ""

        if let publishedAtString = try? container.decode(String.self, forKey: .publishedAt) {
            self.publishedAt = ISO8601DateFormatter().date(from: publishedAtString)
        } else {
            self.publishedAt = nil
        }

        if let user = try? container.decode(UserDTO.self, forKey: .user) {
            self.authorName = user.name
        } else {
            self.authorName = ""
        }

        self.bodyMarkdown = try? container.decode(String.self, forKey: .bodyMarkdown)
        self.bodyHTML = try? container.decode(String.self, forKey: .bodyHTML)
    }
}

