//
//  AppsOnboardingView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 16/05/25.
//

import SwiftUI

public struct AppsOnboardingView: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    @State private var index = 0
    let viewModel: AppsOnboardingViewModel
    
    public init(viewModel: AppsOnboardingViewModel) {
        self.viewModel = viewModel
    }
    
    private var isLastPage: Bool { index == viewModel.pages.count - 1 }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLastPage {
                    Button("Skip", action: finish)
                        .foregroundStyle(Forest.inkMuted)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, Forest.Space.l)
            
            TabView(selection: $index) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { offset, page in
                    pageView(page)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            pageDots
                .padding(.bottom, Forest.Space.xl)
            
            Button(isLastPage ? "Start learning" : "Next") {
                if isLastPage {
                    finish()
                } else {
                    withAnimation { index += 1 }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Forest.Space.l)
            .padding(.bottom, Forest.Space.l)
        }
        .background(Forest.canvas)
    }
    
    private func pageView(_ page: AppsOnboardingViewModel.Page) -> some View {
        VStack(spacing: Forest.Space.xl) {
            Spacer()
            PracticeCells(text: page.character, cellSize: 132, scalesWithText: false)
                .accessibilityHidden(true)
            VStack(spacing: Forest.Space.m) {
                Text(page.title)
                    .font(.title2.bold())
                    .foregroundStyle(Forest.ink)
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(Forest.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Forest.Space.xl)
            Spacer()
        }
    }
    
    private var pageDots: some View {
        HStack(spacing: Forest.Space.s) {
            ForEach(viewModel.pages.indices, id: \.self) { offset in
                Capsule()
                    .fill(offset == index ? Forest.moss : Forest.line)
                    .frame(width: offset == index ? 20 : 8, height: 8)
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
        .accessibilityElement()
        .accessibilityLabel("Page \(index + 1) of \(viewModel.pages.count)")
    }
    
    private func finish() {
        isOnboardingComplete = true
        withAnimation {
            router.setRoot(.dashboard)
        }
    }
}

#Preview {
    AppsOnboardingView(viewModel: AppsOnboardingViewModel())
}
