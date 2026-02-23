import SwiftUI

@main
struct ArticlesAppApp: App {
    init() {
        RealmConfiguration.configure()
    }

    var body: some Scene {
        WindowGroup {
            let store = RealmArticlesStore()
            let api = ForemArticlesAPI()
            let repo = ArticlesRepositoryImpl(api: api, store: store)
            let vm = ArticlesListViewModel(repository: repo)
            ArticlesListView(viewModel: vm)
        }
    }
}
