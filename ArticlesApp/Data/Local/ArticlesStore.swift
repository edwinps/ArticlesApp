import Foundation
import RealmSwift
import Realm

protocol ArticlesStore: Sendable {
    func observeArticles(searchText: String?, author: String?) -> AsyncStream<[Article]>
    func observeArticles() -> AsyncStream<[Article]>
    func observeArticle(id: String) -> AsyncStream<Article?>
    func upsert(articles: [Article]) async throws
    func upsert(detail: Article) async throws
}

final class RealmArticlesStore: ArticlesStore {
    private let configuration: Realm.Configuration
    private let writeQueue = DispatchQueue(label: "RealmArticlesStore.writeQueue", qos: .userInitiated)
    private let observeThread = RunLoopThread(name: "RealmArticlesStore.observeThread")

    init(configuration: Realm.Configuration = .defaultConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Observing

    func observeArticles(searchText: String?, author: String?) -> AsyncStream<[Article]> {
        let config = configuration
        let q = searchText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = author?.trimmingCharacters(in: .whitespacesAndNewlines)

        return AsyncStream { continuation in
            observeThread.perform {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: config)

                        var predicates: [NSPredicate] = []

                        if let q, !q.isEmpty {
                            predicates.append(
                                NSPredicate(
                                    format: "title CONTAINS[c] %@ OR summary CONTAINS[c] %@ OR author CONTAINS[c] %@",
                                    q, q, q
                                )
                            )
                        }

                        if let a, !a.isEmpty {
                            predicates.append(NSPredicate(format: "author == %@", a))
                        }

                        let finalPredicate: NSPredicate? = predicates.isEmpty
                            ? nil
                            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

                        var results = realm.objects(RealmArticle.self)
                        if let finalPredicate { results = results.filter(finalPredicate) }
                        results = results.sorted(byKeyPath: "publishedAt", ascending: false)

                        // Emit initial snapshot
                        continuation.yield(results.map { $0.toDomain() })

                        let token = results.observe { change in
                            switch change {
                            case .initial(let collection),
                                 .update(let collection, _, _, _):
                                continuation.yield(collection.map { $0.toDomain() })
                            case .error:
                                continuation.finish()
                            }
                        }

                        continuation.onTermination = { @Sendable _ in
                            self.observeThread.perform {
                                token.invalidate()
                            }
                        }
                    } catch {
                        continuation.finish()
                    }
                }
            }
        }
    }

    func observeArticles() -> AsyncStream<[Article]> {
        observeArticles(searchText: nil, author: nil)
    }

    func observeArticle(id: String) -> AsyncStream<Article?> {
        let config = configuration
        let articleId = id

        return AsyncStream { continuation in
            observeThread.perform {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: config)

                        let results = realm.objects(RealmArticle.self)
                            .where { $0.id == articleId }

                        continuation.yield(results.first?.toDomain())

                        let token = results.observe { change in
                            switch change {
                            case .initial(let collection),
                                 .update(let collection, _, _, _):
                                continuation.yield(collection.first?.toDomain())
                            case .error:
                                continuation.finish()
                            }
                        }

                        continuation.onTermination = { @Sendable _ in
                            self.observeThread.perform {
                                token.invalidate()
                            }
                        }
                    } catch {
                        continuation.finish()
                    }
                }
            }
        }
    }

    // MARK: - Writing

    func upsert(articles: [Article]) async throws {
        guard !articles.isEmpty else { return }
        let config = configuration
        let items = articles

        try await withCheckedThrowingContinuation { continuation in
            writeQueue.async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: config)
                        let realmObjects = items.map { RealmArticle(from: $0) }

                        try realm.write {
                            realm.add(realmObjects, update: .modified)
                        }

                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func upsert(detail: Article) async throws {
        let config = configuration
        let item = detail

        try await withCheckedThrowingContinuation { continuation in
            writeQueue.async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: config)

                        try realm.write {
                            if let existing = realm.object(ofType: RealmArticle.self, forPrimaryKey: item.id) {
                                existing.title = item.title
                                existing.summary = item.summary
                                existing.author = item.author
                                existing.publishedAt = item.publishedAt
                                existing.updatedAt = Date()

                                if !item.content.isEmpty {
                                    existing.content = item.content
                                    existing.contentUpdatedAt = Date()
                                }
                            } else {
                                let created = RealmArticle(from: item)
                                realm.add(created, update: .modified)
                            }
                        }

                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

// We manage thread-safety internally via a dedicated run loop thread and a serial write queue.
extension RealmArticlesStore: @unchecked Sendable {}
