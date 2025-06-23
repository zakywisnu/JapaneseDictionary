import SwiftUI
import SwiftUIApps
import DomainKit
import ZeroDesignKit
import ZeroCoreKit
import DataKit

@main
struct JapaneseDictionaryApp: App {
    @StateObject var router: AppRouter = .init(root: .splashScreen)
    @StateObject var appTabs: AppTabsViewModel = .init(appTab: .home)
    
    init() {
        UIView.appearance().overrideUserInterfaceStyle = .light
    }
    
    var body: some Scene {
        WindowGroup {
            RouterView()
                .designKitInjection()
                .swiftUIRouterInjection(router)
                .environmentObject(appTabs)
        }
    }
}
