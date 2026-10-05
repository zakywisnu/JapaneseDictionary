import SwiftUI
import SwiftUIApps

@main
struct JapaneseDictionaryApp: App {
    @StateObject var router: AppRouter = .init(root: .splashScreen)
    @StateObject var appTabs: AppTabsViewModel = .init(appTab: .home)
    
    var body: some Scene {
        WindowGroup {
            AppNavigationStack(router: router) {
                RouterView()
            }
            .environmentObject(appTabs)
        }
    }
}
