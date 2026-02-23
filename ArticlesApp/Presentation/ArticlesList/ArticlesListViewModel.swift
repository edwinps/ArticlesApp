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

    // Estado público único
    var state: ArticlesListState = .loading

    // MARK: - Search
    var searchQuery: String = "" {
        didSet { recomputeState() }
    }

    private let repository: ArticlesRepository
    private var observeTask: Task<Void, Never>?
    private var isLoadingMore = false
    private var didInitialSync = false

    // Colección completa interna (sin filtrar)
    private var allArticles: [Article] = [] {
        didSet { recomputeState() }
    }

    init(repository: ArticlesRepository) {
        self.repository = repository
    }

    func makeDetailViewModel(id: String) -> ArticleDetailViewModel {
        ArticleDetailViewModel(articleId: id, repository: repository)
    }

    func send(_ event: Event) async {
        switch event {
        case .start:
            start()
        case .stop:
            stop()
        case .refresh:
            await refresh()
        case .loadMore:
            await loadMore()
        }
    }
}

private extension ArticlesListViewModel {
    func start() {
        observeTask?.cancel()

        let repository = self.repository
        observeTask = Task { [weak self] in
            for await list in repository.observeArticles() {
                guard let self else { return }
                self.allArticles = list
                if list.isEmpty {
                    self.state = (self.didInitialSync ? .empty : .loading)
                } else {
                    // recomputeState() ya pone .loaded con el filtro aplicado
                    self.recomputeState()
                }
            }
        }

        if !didInitialSync {
            didInitialSync = true
            Task {
                try? await repository.fetchArticles(forceRefresh: true)
            }
        }
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil
    }

    func refresh() async {
        do {
            try await repository.fetchArticles(forceRefresh: true)
        } catch {
            if allArticles.isEmpty {
                state = .error(error.localizedDescription)
            }
        }
    }

    func loadMore() async {
        // No cargar más mientras hay búsqueda activa
        guard !isSearching else { return }
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            try await repository.fetchArticles(forceRefresh: false)
        } catch { }
    }

    // MARK: - Filtering
    var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func recomputeState() {
        // Si no hay artículos en absoluto, mantener empty/loading según corresponda
        guard !allArticles.isEmpty else {
            state = didInitialSync ? .empty : .loading
            return
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let items: [Article]
        if query.isEmpty {
            items = allArticles
        } else {
            items = allArticles.filter { matches(article: $0, query: query) }
        }
        state = .loaded(items)
    }

    func matches(article: Article, query: String) -> Bool {
        let q = query.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        func norm(_ s: String) -> String {
            s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        }
        return norm(article.title).contains(q)
            || norm(article.summary).contains(q)
            || norm(article.author).contains(q)
    }
}

