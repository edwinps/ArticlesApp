// Domain/Models/Article.swift

import Foundation

struct Article: Sendable, Hashable {
    let id: String
    let title: String
    let summary: String
    let author: String
    let publishedAt: Date
    let content: String

    init(
        id: String,
        title: String,
        summary: String,
        author: String,
        publishedAt: Date,
        content: String = ""
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.author = author
        self.publishedAt = publishedAt
        self.content = content
    }
}

extension Article {
    init(values: (id: String, title: String, summary: String, author: String,
                  publishedAt: Date, content: String)) {
        self.init(
            id: values.id,
            title: values.title,
            summary: values.summary,
            author: values.author,
            publishedAt: values.publishedAt,
            content: values.content
        )
    }
    init(realmObject realm: RealmArticle) {
        self.init(
            id: realm.id,
            title: realm.title,
            summary: realm.summary,
            author: realm.author,
            publishedAt: realm.publishedAt,
            content: realm.content
        )
    }
}

