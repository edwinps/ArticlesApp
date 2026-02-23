// Features/ArticleDetail/ArticleDetailView.swift

import SwiftUI
import Observation

struct ArticleDetailView: View {
    @Bindable var viewModel: ArticleDetailViewModel
    @State private var didStart = false

    init(viewModel: ArticleDetailViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .content:
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let article = viewModel.article {
                            Text(article.title)
                                .font(.title)
                                .fontWeight(.bold)

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
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(article.content)
                                    .font(.body)
                            }
                        } else {
                            Text("No article data available.")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .refreshable {
                    await viewModel.send(.refresh)
                }

            case .missingOffline:
                ScrollView {
                    VStack(spacing: 12) {
                        Text("This article is not available offline yet.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
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
                    .padding()
                }
                .refreshable {
                    await viewModel.send(.refresh)
                }
            }
        }
        .navigationTitle("Article")
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

#Preview {
    let store = RealmArticlesStore()
    let api = ForemArticlesAPI()
    let repo = ArticlesRepositoryImpl(api: api, store: store)
    let vm = ArticleDetailViewModel(articleId: "preview-id", repository: repo)
    return NavigationView {
        ArticleDetailView(viewModel: vm)
    }
}
