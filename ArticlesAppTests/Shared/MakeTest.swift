//
//  MakeTest.swift
//  ArticlesAppTests
//
//  Created by Edwinps on 24/2/26.
//

import Foundation
import Testing
@testable import ArticlesApp

enum TestFixtures {
    static func makeArticleDTO(
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(ArticleDTO.self, from: data)
        } catch {
            fatalError("Adjust fixture keys to match ArticleDTO CodingKeys. Error: \(error)")
        }
    }

    static func makeArticleDetailDTO(
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(ArticleDetailDTO.self, from: data)
        } catch {
            fatalError("Adjust fixture keys to match ArticleDetailDTO CodingKeys. Error: \(error)")
        }
    }

    static func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        return f.string(from: date)
    }

    static func escapeJSON(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
