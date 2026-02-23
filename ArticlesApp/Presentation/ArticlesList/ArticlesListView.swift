import SwiftUI
import Observation

struct ArticlesListView: View {
    @State var viewModel: ArticlesListViewModel
    @State private var didStart = false

    init(viewModel: ArticlesListViewModel) {
        _viewModel = State(initialValue: viewModel)
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
                            NavigationLink(value: article.id) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(article.title)
                                        .font(.headline)
                                        .lineLimit(2)
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
            .navigationDestination(for: String.self) { id in
                ArticleDetailView(viewModel: viewModel.makeDetailViewModel(id: id))
            }
            .navigationTitle("Articles")
            .searchable(text: $viewModel.searchQuery, prompt: "Search articles")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Author", selection: $viewModel.authorFilter) {
                            Text("All authors").tag(String?.none)
                            ForEach(viewModel.availableAuthors, id: \.self) { author in
                                Text(author).tag(Optional(author))
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
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

#Preview("Light") {
    let store = RealmArticlesStore()
    let api = ForemArticlesAPI()
    let repo = ArticlesRepositoryImpl(api: api, store: store)
    let vm = ArticlesListViewModel(repository: repo)
    return ArticlesListView(viewModel: vm)
}

#Preview("Dark") {
    let store = RealmArticlesStore()
    let api = ForemArticlesAPI()
    let repo = ArticlesRepositoryImpl(api: api, store: store)
    let vm = ArticlesListViewModel(repository: repo)
    return ArticlesListView(viewModel: vm)
        .preferredColorScheme(.dark)
}
