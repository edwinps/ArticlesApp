//
//  ArticlesStore.swift
//  ArticlesApp
//
//

import Foundation
import RealmSwift
import Realm

protocol ArticlesStore: Sendable {
    func observeArticles() -> AsyncStream<[Article]>
    func observeArticle(id: String) -> AsyncStream<Article?>
    func upsert(articles: [Article]) async throws
    func upsert(detail: Article) async throws
}

final class NotificationTokenBox: @unchecked Sendable {
    private let lock = NSLock()
    private var token: NotificationToken?
    
    func set(_ newToken: NotificationToken?) {
        lock.lock()
        token = newToken
        lock.unlock()
    }
    
    func invalidateAndClear() {
        lock.lock()
        let current = token
        token = nil
        lock.unlock()
        current?.invalidate()
    }
}

final class RealmArticlesStore: ArticlesStore {
    private let configuration: Realm.Configuration
    private let writeQueue = DispatchQueue(label: "RealmArticlesStore.writeQueue", qos: .userInitiated)
    
    init(configuration: Realm.Configuration = .defaultConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: Observing
    
    func observeArticles() -> AsyncStream<[Article]> {
        let config = configuration
        
        return AsyncStream { continuation in
            let box = NotificationTokenBox()
            
            do {
                let realm = try Realm(configuration: config)
                
                let results = realm.objects(RealmArticle.self)
                    .sorted(byKeyPath: "publishedAt", ascending: false)
                
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
                box.set(token)
                
                continuation.onTermination = { @Sendable _ in
                    box.invalidateAndClear()
                }
            } catch {
                continuation.finish()
            }
        }
    }
    
    func observeArticle(id: String) -> AsyncStream<Article?> {
        let config = configuration
        let articleId = id
        
        return AsyncStream { continuation in
            let box = NotificationTokenBox()
            
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
                box.set(token)
                
                continuation.onTermination = { @Sendable _ in
                    box.invalidateAndClear()
                }
            } catch {
                continuation.finish()
            }
        }
    }
    
    // MARK: Writing
    
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
                        
                        continuation.resume()
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
                        
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
