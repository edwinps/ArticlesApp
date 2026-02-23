import Foundation
import Observation

enum ArticleDetailState: Equatable, Sendable {
    case idle
    case loading
    case error(String)
}

@MainActor
@Observable
final class ArticleDetailViewModel {
    enum Event: Sendable { case start, stop, refresh }

    var article: Article? = nil
    var state: ArticleDetailState = .idle
    var isMissingOffline: Bool = false

    let articleId: String
    private let repository: ArticlesRepository
    private let logger: AppLogger

    private var articleObserveTask: Task<Void, Never>?
    private var didPerformAutoRefresh = false
    private var hasStartedObserving = false
    private var isRefreshing = false

    init(articleId: String, repository: ArticlesRepository, logger: AppLogger = DefaultLogger.shared) {
        self.articleId = articleId
        self.repository = repository
        self.logger = logger
    }

    func send(_ event: Event) async {
        switch event {
        case .start: start()
        case .stop: stop()
        case .refresh: await refresh(isAutomatic: false)
        }
    }
}

private extension ArticleDetailViewModel {
    func start() {
        guard !hasStartedObserving else { return }
        hasStartedObserving = true

        articleObserveTask?.cancel()
        didPerformAutoRefresh = false
        isRefreshing = false
        state = .idle
        isMissingOffline = false

        logger.info("ArticleDetailViewModel.start observing id=\(articleId)")

        articleObserveTask = Task { [weak self] in
            guard let self else { return }
            for await article in self.repository.observeArticle(id: self.articleId) {
                self.article = article
                self.isMissingOffline = (article == nil)

                if let article {
                    self.logger.debug("Observed article id=\(article.id) contentEmpty=\(article.content.isEmpty)")
                } else {
                    self.logger.debug("Observed article is nil (not cached offline) id=\(self.articleId)")
                }

                if let article, article.content.isEmpty, !self.didPerformAutoRefresh {
                    self.didPerformAutoRefresh = true
                    self.logger.info("Auto-refresh triggered due to missing content id=\(self.articleId)")
                    Task { [weak self] in
                        await self?.refresh(isAutomatic: true)
                    }
                }
            }
        }
    }

    func stop() {
        logger.info("ArticleDetailViewModel.stop observing id=\(articleId)")
        articleObserveTask?.cancel()
        articleObserveTask = nil
        hasStartedObserving = false
    }

    private func refresh(isAutomatic: Bool) async {
        guard !isRefreshing else {
            logger.debug("Refresh skipped (already in progress) id=\(articleId)")
            return
        }
        isRefreshing = true
        logger.info("Refresh begin id=\(articleId) automatic=\(isAutomatic)")
        state = .loading

        defer {
            isRefreshing = false
            if case .loading = state { state = .idle }
        }

        do {
            try await repository.fetchArticleDetail(id: articleId)
            state = .idle
            logger.info("Refresh success id=\(articleId)")
        } catch is CancellationError {
            logger.warning("Refresh cancelled id=\(articleId)")
            state = .idle
        } catch let error as NetworkError {
            if case .offline = error {
                if article == nil { isMissingOffline = true }
                state = .idle
                logger.warning("Refresh offline id=\(articleId) cachedExists=\(article != nil)")
            } else {
                let message = error.localizedDescription
                state = .error(message)
                logger.error(error, message: "Refresh failed (NetworkError) id=\(articleId)")
            }
        } catch {
            let message = error.localizedDescription
            state = .error(message)
            logger.error(error, message: "Refresh failed (unknown) id=\(articleId)")
        }
    }
}
