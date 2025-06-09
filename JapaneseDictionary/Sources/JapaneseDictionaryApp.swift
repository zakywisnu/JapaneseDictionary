import SwiftUI
import SwiftUIApps
import DomainKit
import ZeroDesignKit
import ZeroCoreKit
import DataKit

@main
struct JapaneseDictionaryApp: App {
    @StateObject var router: AppRouter = .init(root: .splashScreen)
    
    init() {
        UIView.appearance().overrideUserInterfaceStyle = .light
    }
    
    var body: some Scene {
        WindowGroup {
            RouterView()
                .designKitInjection()
                .swiftUIRouterInjection(router)
        }
    }
}
