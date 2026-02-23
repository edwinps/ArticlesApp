import SwiftUI

@main
struct ArticlesAppApp: App {
    private let store: RealmArticlesStore
    private let api: ForemArticlesAPI
    private let repo: ArticlesRepositoryImpl
    private let vm: ArticlesListViewModel

    init() {
        RealmConfiguration.configure()

        let store = RealmArticlesStore()
        let api = ForemArticlesAPI()
        let repo = ArticlesRepositoryImpl(api: api, store: store)
        let vm = ArticlesListViewModel(repository: repo)

        self.store = store
        self.api = api
        self.repo = repo
        self.vm = vm
    }

    var body: some Scene {
        WindowGroup {
            ArticlesListView(viewModel: vm)
        }
    }
}
