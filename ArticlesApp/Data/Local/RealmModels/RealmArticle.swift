import Foundation
import RealmSwift
import Realm

final class RealmArticle: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var title: String
    @Persisted var summary: String
    @Persisted var author: String
    @Persisted var publishedAt: Date
    @Persisted var content: String
    @Persisted var updatedAt: Date
    @Persisted var contentUpdatedAt: Date?
    
    override init() {
        super.init()
    }

    convenience init(from article: Article) {
        self.init()
        self.id = article.id
        self.title = article.title
        self.summary = article.summary
        self.author = article.author
        self.publishedAt = article.publishedAt
        self.content = article.content
        self.updatedAt = Date()
        if !article.content.isEmpty {
            self.contentUpdatedAt = Date()
        }
    }

    func toDomain() -> Article {
        Article(
            id: id,
            title: title,
            summary: summary,
            author: author,
            publishedAt: publishedAt,
            content: content
        )
    }
}
