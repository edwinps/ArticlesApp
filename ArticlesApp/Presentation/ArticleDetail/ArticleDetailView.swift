import SwiftUI
import Observation

struct ArticleDetailView: View {
    @State var viewModel: ArticleDetailViewModel
    @State private var didStart = false

    init(viewModel: ArticleDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            content

            if case .loading = viewModel.state, viewModel.article != nil {
                VStack {
                    ProgressView()
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if case .error(let message) = viewModel.state, viewModel.article != nil {
                VStack {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.red.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("Article")
        .refreshable { await viewModel.send(.refresh) }
        .task {
            guard !didStart else { return }
            didStart = true
            await viewModel.send(.start)
        }
        .onDisappear {
            Task { await viewModel.send(.stop) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let article = viewModel.article {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(article.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .lineLimit(3)

                    HStack(spacing: 8) {
                        Text(article.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(article.publishedAt, format: .dateTime.year().month().day())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    if article.content.isEmpty {
                        Text("Content not available offline yet.")
                            .foregroundColor(.secondary)
                    } else {
                        Text(article.content)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

        } else if viewModel.isMissingOffline {
            ScrollView {
                VStack(spacing: 12) {
                    Text("This article is not available offline yet.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }

        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("Light") {
    let store = RealmArticlesStore()
    let api = ForemArticlesAPI()
    let repo = ArticlesRepositoryImpl(api: api, store: store)
    let vm = ArticleDetailViewModel(articleId: "preview-id", repository: repo)
    return NavigationStack {
        ArticleDetailView(viewModel: vm)
    }
}

#Preview("Dark") {
    let store = RealmArticlesStore()
    let api = ForemArticlesAPI()
    let repo = ArticlesRepositoryImpl(api: api, store: store)
    let vm = ArticleDetailViewModel(articleId: "preview-id", repository: repo)
    return NavigationStack {
        ArticleDetailView(viewModel: vm)
            .preferredColorScheme(.dark)
    }
}
