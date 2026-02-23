import Foundation
import Observation

enum ArticlesListState: Equatable, Sendable {
    case loading
    case loaded([Article])
    case empty
    case error(String)
}

@MainActor
@Observable
final class ArticlesListViewModel {
    enum Event: Sendable {
        case start
        case stop
        case refresh
        case loadMore
    }

    var state: ArticlesListState = .loading
    var searchQuery: String = "" {
        didSet {
            logger.debug("Search query changed '\(oldValue)' -> '\(searchQuery)'")
            scheduleSearchDebounce()
        }
    }
    var authorFilter: String? {
        didSet {
            logger.info("Author filter changed to '\(authorFilter ?? "nil")'")
            startArticlesObservation(normalizedQuery: normalizedQuery(searchQuery))
        }
    }
    var availableAuthors: [String] {
        Array(allAuthors).sorted()
    }
    
    private let repository: ArticlesRepository
    private let logger: AppLogger

    private var articlesObserveTask: Task<Void, Never>?
    private var authorsObserveTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?

    private var isLoadingNextPage = false
    private var didPerformInitialFetch = false

    private var currentPage: Int = 0
    private let pageSize: Int = 20

    private var allAuthors: Set<String> = []

    init(repository: ArticlesRepository, logger: AppLogger = DefaultLogger.shared) {
        self.repository = repository
        self.logger = logger
    }

    func makeDetailViewModel(id: String) -> ArticleDetailViewModel {
        ArticleDetailViewModel(articleId: id, repository: repository, logger: logger)
    }

    func send(_ event: Event) async {
        switch event {
        case .start:
            logger.info("ArticlesListViewModel.start")
            start()
        case .stop:
            logger.info("ArticlesListViewModel.stop")
            stop()
        case .refresh:
            logger.info("ArticlesListViewModel.refresh")
            await refresh()
        case .loadMore:
            logger.info("ArticlesListViewModel.loadMore")
            await loadMore()
        }
    }
}

private extension ArticlesListViewModel {
    func start() {
        startArticlesObservation(normalizedQuery: normalizedQuery(searchQuery))
        startAuthorsObservation()

        if !didPerformInitialFetch {
            didPerformInitialFetch = true
            currentPage = 0
            Task {
                await fetchPage(1)
            }
        }
    }

    func stop() {
        articlesObserveTask?.cancel()
        articlesObserveTask = nil

        authorsObserveTask?.cancel()
        authorsObserveTask = nil

        searchDebounceTask?.cancel()
        searchDebounceTask = nil

        logger.debug("Observations cancelled")
    }

    func refresh() async {
        currentPage = 0
        await fetchPage(1)
    }

    func loadMore() async {
        guard !isSearching else {
            logger.debug("Skipping loadMore due to active search")
            return
        }
        guard !isLoadingNextPage else { return }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        let nextPage = currentPage + 1
        await fetchPage(nextPage)
    }

    func fetchPage(_ page: Int) async {
        do {
            logger.info("Fetching page \(page) pageSize=\(pageSize)")
            try await repository.fetchArticles(page: page, perPage: pageSize)
            currentPage = max(currentPage, page)
            logger.debug("Fetch success page=\(page)")
        } catch is CancellationError {
            logger.warning("Fetch cancelled page=\(page)")
        } catch {
            logger.error(error, message: "Fetch failed page=\(page)")
            if case .loaded(let items) = state, items.isEmpty {
                state = .error(error.localizedDescription)
            } else if case .loading = state {
                state = .error(error.localizedDescription)
            }
        }
    }

    func startArticlesObservation(normalizedQuery: String) {
        articlesObserveTask?.cancel()

        let repository = self.repository
        let normalizedQueryOrNil = normalizedQuery.isEmpty ? nil : normalizedQuery
        let normalizedAuthorFilter: String? = {
            guard let authorFilter else { return nil }
            let value = self.normalizedQuery(authorFilter)
            return value.isEmpty ? nil : value
        }()

        logger.info("Start observing list query='\(normalizedQueryOrNil ?? "nil")' authorFilter='\(normalizedAuthorFilter ?? "nil")'")

        articlesObserveTask = Task { [weak self] in
            for await articles in repository.observeArticles(searchText: normalizedQueryOrNil, author: normalizedAuthorFilter) {
                guard let self else { return }
                if articles.isEmpty {
                    self.state = (self.didPerformInitialFetch ? .empty : .loading)
                    self.logger.debug("Observed empty list didInitialFetch=\(self.didPerformInitialFetch)")
                } else {
                    self.state = .loaded(articles)
                    self.logger.debug("Observed list count=\(articles.count)")
                }
            }
        }
    }

    func startAuthorsObservation() {
        authorsObserveTask?.cancel()

        let repository = self.repository
        authorsObserveTask = Task { [weak self] in
            for await articles in repository.observeArticles() {
                guard let self else { return }
                let newAuthors = Set(articles.map { $0.author })
                let addedAuthors = newAuthors.subtracting(self.allAuthors)
                self.allAuthors = newAuthors
                if !addedAuthors.isEmpty {
                    self.logger.debug("Authors updated total=\(self.allAuthors.count)")
                }
            }
        }
    }

    func scheduleSearchDebounce() {
        searchDebounceTask?.cancel()
        let normalized = normalizedQuery(searchQuery)

        searchDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                self?.logger.debug("Search debounce fired query='\(normalized)'")
                self?.startArticlesObservation(normalizedQuery: normalized)
            } catch { }
        }
    }

    func normalizedQuery(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearching: Bool {
        !normalizedQuery(searchQuery).isEmpty
    }
}
