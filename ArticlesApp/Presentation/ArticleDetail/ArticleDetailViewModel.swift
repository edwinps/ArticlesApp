// Features/ArticleDetail/ArticleDetailViewModel.swift

import Foundation
import Observation

enum ArticleDetailState: Equatable, Sendable {
    case loading
    case content
    case missingOffline
    case error(String)
}

@MainActor
@Observable
final class ArticleDetailViewModel {
    enum Event: Sendable {
        case start
        case stop
        case refresh
    }

    var article: Article?
    var state: ArticleDetailState = .loading

    let articleId: String

    private let repository: ArticlesRepository
    private var observeTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?
    private var didAutoRefresh = false

    init(articleId: String, repository: ArticlesRepository) {
        self.articleId = articleId
        self.repository = repository
    }

    func send(_ event: Event) async {
        switch event {
        case .start:
            start()
        case .stop:
            stop()
        case .refresh:
            await refresh()
        }
    }
}

private extension ArticleDetailViewModel {
    func start() {
        observeTask?.cancel()
        autoRefreshTask?.cancel()

        let repository = self.repository
        let id = self.articleId

        observeTask = Task { [weak self] in
            for await item in repository.observeArticle(id: id) {
                guard let self else { return }
                self.article = item

                if let item {
                    self.state = .content
                    if item.content.isEmpty {
                        await self.tryAutoRefreshIfNeeded()
                    }
                } else {
                    self.state = .missingOffline
                }
            }
        }
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil

        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    func refresh() async {
        do {
            try await repository.fetchArticleDetail(id: articleId)
        } catch let error as NetworkError {
            if case .offline = error {
                if article == nil {
                    state = .missingOffline
                }
            } else {
                if article == nil {
                    state = .error(error.localizedDescription)
                }
            }
        } catch {
            if article == nil {
                state = .error(error.localizedDescription)
            }
        }
    }

    func tryAutoRefreshIfNeeded() async {
        guard !didAutoRefresh else { return }
        guard let current = article, current.content.isEmpty else { return }
        guard autoRefreshTask == nil else { return }

        didAutoRefresh = true
        autoRefreshTask = Task { [weak self] in
            guard let self else { return }
            defer { Task { @MainActor in self.autoRefreshTask = nil } }
            do {
                try await self.repository.fetchArticleDetail(id: self.articleId)
            } catch let error as NetworkError {
                if case .offline = error {
                    return
                } else if self.article == nil {
                    await MainActor.run { self.state = .error(error.localizedDescription) }
                }
            } catch {
                if self.article == nil {
                    await MainActor.run { self.state = .error(error.localizedDescription) }
                }
            }
        }
    }
}
