//
//  AppSplashScreen.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 16/05/25.
//

import SwiftUI
import ZeroCoreKit
import ZeroDesignKit

public struct AppSplashScreen: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    
    public init() {}
    
    public var body: some View {
        VStack {
            Text("言葉の森")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(DefaultColors.primary)
            
            Text("Your gateway to mastering Japanese.")
                .font(.body)
                .foregroundColor(DefaultColors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DefaultColors.background.opacity(0.4))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    if isOnboardingComplete {
                        router.setRoot(.dashboard, hideNavBar: true)
                    } else {
                        router.setRoot(.onboarding, hideNavBar: true)
//                        isOnboardingComplete = true
                    }
                }
            }
        }
    }
}

struct FirstAppearanceActionModifier: ViewModifier {
    var action: (() -> Void)?

    @State private var didFirstAppear: Bool = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !didFirstAppear else { return }
                didFirstAppear = true
                action?()
            }
    }
}

public extension View {
    /// Adds an action to perform when this view appears for the first time.
    ///
    /// - Parameter action: The action to perform. If `action` is `nil`, the
    ///   call has no effect.
    ///
    /// - Returns: A view that triggers `action` when this view appears for the first time.
    func onFirstAppear(perform action: (() -> Void)? = nil) -> some View {
        modifier(FirstAppearanceActionModifier(action: action))
    }
}

