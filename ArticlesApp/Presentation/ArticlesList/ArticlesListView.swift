import SwiftUI
import Observation

struct ArticlesListView: View {
    @Bindable var viewModel: ArticlesListViewModel
    @State private var didStart = false

    init(viewModel: ArticlesListViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .empty:
                    ScrollView {
                        VStack(spacing: 12) {
                            Text("No articles yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .refreshable {
                        await viewModel.send(.refresh)
                    }

                case .error(let message):
                    ScrollView {
                        VStack(spacing: 12) {
                            Text(message)
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .refreshable {
                        await viewModel.send(.refresh)
                    }

                case .loaded(let items):
                    ZStack {
                        List(items, id: \.id) { article in
                            NavigationLink {
                                let detailVM = viewModel.makeDetailViewModel(id: article.id)
                                ArticleDetailView(viewModel: detailVM)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(article.title)
                                        .font(.headline)
                                    Text(article.summary)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 8) {
                                        Text(article.author)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(article.publishedAt, format: .dateTime.year().month().day())
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onAppear {
                                if article.id == items.last?.id {
                                    Task { await viewModel.send(.loadMore) }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await viewModel.send(.refresh)
                        }

                        // Si hay artículos en la base pero el filtro devolvió 0
                        if items.isEmpty {
                            VStack(spacing: 8) {
                                Text("No results")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Try a different search term.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Articles")
            .searchable(text: $viewModel.searchQuery, prompt: "Search articles")
            .task {
                guard !didStart else { return }
                didStart = true
                await viewModel.send(.start)
            }
            .onDisappear {
                Task { await viewModel.send(.stop) }
            }
        }
    }
}

#Preview {
    let store = RealmArticlesStore()
    let api = ForemArticlesAPI()
    let repo = ArticlesRepositoryImpl(api: api, store: store)
    let vm = ArticlesListViewModel(repository: repo)
    return ArticlesListView(viewModel: vm)
}

