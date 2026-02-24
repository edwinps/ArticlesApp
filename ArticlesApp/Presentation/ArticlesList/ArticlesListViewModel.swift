import Foundation
import Observation



@MainActor
@Observable
final class ArticlesListViewModel {
    enum ArticlesListState: Equatable, Sendable {
        case loading
        case loaded([Article])
        case empty
        case error(String)
    }
    
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
            applyFiltersAndUpdateState()
        }
    }
    var availableAuthors: [String] {
        Array(allAuthors).sorted()
    }
    
    private let repository: ArticlesRepository
    private let logger: AppLogger
    private var observeAllTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?
    private var allArticles: [Article] = []
    private var allAuthors: Set<String> = []
    
    private var isLoadingNextPage = false
    private var didPerformInitialFetch = false
    private var currentPage: Int = 0
    private let pageSize: Int = 20
    private var hasMore: Bool = true
    
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
        startObservingAllArticles()
        
        if !didPerformInitialFetch {
            didPerformInitialFetch = true
            currentPage = 0
            hasMore = true
            state = .loading
            
            Task {
                await fetchPage(1)
            }
        } else {
            applyFiltersAndUpdateState()
        }
    }
    
    func stop() {
        observeAllTask?.cancel()
        observeAllTask = nil
        
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        
        logger.debug("Observations cancelled")
    }
    
    func startObservingAllArticles() {
        observeAllTask?.cancel()
        
        let repository = self.repository
        observeAllTask = Task { [weak self] in
            for await list in repository.observeArticles() {
                guard let self else { return }
                self.allArticles = list
                self.allAuthors = Set(list.map { $0.author })
                self.logger.debug("Observed allArticles count=\(list.count) authors=\(self.allAuthors.count)")
                self.applyFiltersAndUpdateState()
            }
        }
    }
    
    func applyFiltersAndUpdateState() {
        let filtered = filteredArticles()
        
        if filtered.isEmpty {
            if !didPerformInitialFetch || (currentPage == 0 && hasMore) {
                if !allArticles.isEmpty, isSearchingOrFiltering {
                    state = .loaded([])
                } else if allArticles.isEmpty {
                    state = .loading
                } else {
                    state = .empty
                }
            } else {
                if allArticles.isEmpty {
                    state = .empty
                } else {
                    state = .loaded([])
                }
            }
        } else {
            state = .loaded(filtered)
        }
    }
    
    func filteredArticles() -> [Article] {
        let query = normalized(searchQuery)
        let author = normalized(authorFilter)
        if query.isEmpty, author == nil { return allArticles }
        return allArticles.filter { article in
            if let author, normalized(article.author) != author {
                return false
            }
            guard !query.isEmpty else { return true }
            
            return article.title.localizedCaseInsensitiveContains(query)
            || article.summary.localizedCaseInsensitiveContains(query)
            || article.author.localizedCaseInsensitiveContains(query)
        }
    }
    
    var isSearchingOrFiltering: Bool {
        !normalized(searchQuery).isEmpty || normalized(authorFilter) != nil
    }
    
    func normalized(_ text: String?) -> String? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
    
    func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func scheduleSearchDebounce() {
        searchDebounceTask?.cancel()
        let query = searchQuery
        
        searchDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
                guard let self else { return }
                
                self.logger.debug("Search debounce fired query='\(query)'")
                self.applyFiltersAndUpdateState()
            } catch {
                // cancelled
            }
        }
    }
    
    func refresh() async {
        currentPage = 0
        hasMore = true
    }
    
    func loadMore() async {
        guard !isSearchingOrFiltering else {
            logger.debug("Skipping loadMore due to active search/filter")
            return
        }
        guard hasMore else {
            logger.debug("Skipping loadMore (hasMore=false)")
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
            logger.info("Fetching page=\(page) size=\(pageSize)")
            let count = try await repository.fetchArticles(page: page, perPage: pageSize)
            currentPage = max(currentPage, page)
            hasMore = (count == pageSize)
            logger.info("Fetch success page=\(page) count=\(count) hasMore=\(hasMore)")
        } catch is CancellationError {
            logger.warning("Fetch cancelled page=\(page)")
        } catch let error as NetworkError {
            if case .offline = error {
                logger.warning("Fetch offline page=\(page) cachedCount=\(allArticles.count)")
                if allArticles.isEmpty, (state == .loading) {
                    state = .empty
                }
                return
            }
            logger.error(error, message: "Fetch failed page=\(page)")
            if allArticles.isEmpty {
                state = .error(error.localizedDescription)
            }
        } catch {
            logger.error(error, message: "Fetch failed page=\(page)")
            if allArticles.isEmpty {
                state = .error(error.localizedDescription)
            }
        }
    }
}
