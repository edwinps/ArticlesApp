import Foundation
import Observation


@MainActor
@Observable
final class ArticleDetailViewModel {
    enum ArticleDetailState: Equatable, Sendable {
        case idle
        case loading
        case error(String)
    }
    
    enum Event: Sendable {
        case start
        case stop
        case refresh
    }
    
    var article: Article? = nil
    var state: ArticleDetailState = .idle
    var isMissingOffline: Bool = false
    
    let articleId: String
    private let repository: ArticlesRepository
    private let logger: AppLogger
    
    private var observeTask: Task<Void, Never>?
    private var hasStarted = false
    private var didAutoRefresh = false
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
        case .refresh: await refresh()
        }
    }
}

private extension ArticleDetailViewModel {
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        didAutoRefresh = false
        
        logger.info("ArticleDetailViewModel.start observing id=\(articleId)")
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            guard let self else { return }
            
            for await item in repository.observeArticle(id: articleId) {
                self.article = item
                self.isMissingOffline = (item == nil)
                
                if let item {
                    self.logger.debug("Observed article id=\(item.id) contentEmpty=\(item.content.isEmpty)")
                    
                    if item.content.isEmpty, !self.didAutoRefresh {
                        self.didAutoRefresh = true
                        self.logger.info("Auto-refresh triggered due to missing content id=\(articleId)")
                        await self.refresh()
                    }
                } else {
                    self.logger.debug("Observed article is nil (not cached offline) id=\(articleId)")
                }
            }
        }
    }
    
    func stop() {
        logger.info("ArticleDetailViewModel.stop observing id=\(articleId)")
        observeTask?.cancel()
        observeTask = nil
        hasStarted = false
        isRefreshing = false
    }
    
    private func refresh() async {
        guard !isRefreshing else {
            logger.debug("Refresh skipped (already in progress) id=\(articleId)")
            return
        }
        isRefreshing = true
        logger.info("Refresh begin id=\(articleId)")
        state = .loading
        
        defer {
            isRefreshing = false
            if case .loading = state { state = .idle }
        }
        
        do {
            try await repository.fetchArticleDetail(id: articleId)
            logger.info("Refresh success id=\(articleId)")
        } catch is CancellationError {
            logger.warning("Refresh cancelled id=\(articleId)")
        } catch let error as NetworkError {
            if case .offline = error {
                if article == nil { isMissingOffline = true }
                logger.warning("Refresh offline id=\(articleId) cachedExists=\(article != nil)")
            } else {
                if article == nil {
                    state = .error(error.localizedDescription)
                }
                logger.error(error, message: "Refresh failed (NetworkError) id=\(articleId)")
            }
        } catch {
            if article == nil {
                state = .error(error.localizedDescription)
            }
            logger.error(error, message: "Refresh failed (unknown) id=\(articleId)")
        }
    }
}
