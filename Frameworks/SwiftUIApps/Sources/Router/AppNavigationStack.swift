//
//  AppNavigationStack.swift
//  SwiftUIApps
//

import SwiftUI

/// Replaces ZeroCoreKit's router injection, whose path binding ignores writes and so breaks
/// the system back button and swipe-back. Root routes stay out of the stack; `RouterView` shows them.
public struct AppNavigationStack<Content: View>: View {
    @ObservedObject private var router: AppRouter
    private let content: Content

    public init(router: AppRouter, @ViewBuilder content: () -> Content) {
        self.router = router
        self.content = content()
    }

    public var body: some View {
        NavigationStack(path: pushedRoutes) {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoutes.self) { route in
                    route.view()
                        .environmentObject(router)
                }
        }
        .environmentObject(router)
        .tint(Forest.moss)
    }

    private var pushedRoutes: Binding<[AppRoutes]> {
        Binding(
            get: { router.navigationPath.filter(\.isPushed) },
            set: { router.navigationPath = $0 }
        )
    }
}

extension AppRoutes {
    var isPushed: Bool {
        switch self {
        case .difficult, .lessons, .material, .detail, .review, .sources, .backup, .dictionary, .dictionaryEntry, .studyLists, .studyList, .dailyGoal: return true
        default: return false
        }
    }
}
