//
//  AppSplashScreen.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 16/05/25.
//

import SwiftUI
import ZeroCoreKit

public struct AppSplashScreen: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: Forest.Space.l) {
            PracticeCells(text: "言葉の森", cellSize: 64, scalesWithText: false)
            Text("JLPT words and kanji, one at a time")
                .font(.subheadline)
                .foregroundStyle(Forest.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Forest.canvas)
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation {
                router.setRoot(isOnboardingComplete ? .dashboard : .onboarding, hideNavBar: true)
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
    /// Unlike `onAppear`, runs only once even when the view reappears.
    func onFirstAppear(perform action: (() -> Void)? = nil) -> some View {
        modifier(FirstAppearanceActionModifier(action: action))
    }
}

