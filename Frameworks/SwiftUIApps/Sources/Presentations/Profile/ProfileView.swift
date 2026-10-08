//
//  ProfileView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 02/06/25.
//

import SwiftUI

public struct ProfileView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject var appTabs: AppTabsViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var viewModel: ProfileViewModel
    
    public init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                ScreenHeader(title: "Progress")
                
                switch viewModel.state.loadState {
                case .loading:
                    ProgressView("Loading your progress")
                        .frame(maxWidth: .infinity)
                        .padding(.top, Forest.Space.xxl)
                case .failed:
                    StateMessage(
                        title: "Couldn't load your progress",
                        message: "Your saved progress or the bundled word lists didn't load.",
                        actionTitle: "Try again",
                        action: { viewModel.send(.onAppear) }
                    )
                case .loaded:
                    if let progress = viewModel.state.progress {
                        loaded(progress)
                    }
                }
                if let recovery = AppComposer.shared.backupRestoreStatus.recoveryURL {
                    VStack(alignment: .leading, spacing: Forest.Space.m) {
                        Text("Backup restored")
                            .font(.headline)
                        Text("Your collection, study lists, progress, review dates, daily goal and practice history have been replaced. Keep the recovery backup if you want a copy of your previous collection.")
                            .foregroundStyle(Forest.inkMuted)
                        ShareLink("Share recovery backup", item: recovery)
                            .frame(minHeight: 44)
                    }
                    .padding(Forest.Space.l)
                    .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
                }
                Button("Daily practice goal") { router.push(.dailyGoal, hideNavBar: false) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Forest.ink)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Button {
                    router.push(.backup, hideNavBar: false)
                } label: {
                    Text("Backup and restore")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Forest.ink)
                Button {
                    router.push(.sources, hideNavBar: false)
                } label: {
                    Text("Sources")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Forest.ink)
            }
            .padding(.horizontal, Forest.Space.l)
            .padding(.top, Forest.Space.s)
            .padding(.bottom, Forest.Space.xl)
        }
        .background(Forest.canvas)
        .onAppear { viewModel.send(.onAppear) }
    }
    
    @ViewBuilder
    private func loaded(_ progress: WordsProgress) -> some View {
        if progress.kotobaProgress == 0 && progress.kanjiProgress == 0 {
            StateMessage(
                title: "Nothing added yet",
                message: "Add your first word or kanji on Today and your progress starts here.",
                actionTitle: "Go to Today",
                action: { appTabs.appTab = .home }
            )
            .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
        }
        
        trackCard(
            noun: "Words",
            added: progress.kotobaProgress,
            total: viewModel.state.totalKotoba,
            level: progress.kotobaLevel.rawValue,
            lastAdded: progress.kotobaProgress > 0 ? progress.lastKotobaUpdated : nil
        )
        trackCard(
            noun: "Kanji",
            added: progress.kanjiProgress,
            total: viewModel.state.totalKanji,
            level: progress.kanjiLevel.rawValue,
            lastAdded: progress.kanjiProgress > 0 ? progress.lastKanjiUpdated : nil
        )
        
        Text("Counts include preserved words from older lists. The current study list size is shown separately. Progress is saved on this iPhone only. Deleting the app deletes it.")
            .font(.footnote)
            .foregroundStyle(Forest.inkMuted)
    }
    
    private func trackCard(noun: String, added: Int, total: Int, level: String, lastAdded: Date?) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.m) {
            Text("\(noun) in collection")
                .font(.headline)
                .foregroundStyle(Forest.ink)
            
            HStack(alignment: .firstTextBaseline, spacing: Forest.Space.xs) {
                Text(added.formatted())
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(Forest.ink)
                Text(noun == "Words" ? "collected" : "of \(total.formatted())")
                    .font(.subheadline)
                    .foregroundStyle(Forest.inkMuted)
            }
            .accessibilityElement(children: .combine)
            
            if noun == "Words" {
                labeled("Current study list", value: "\(total.formatted()) words")
            }
            if noun != "Words" {
                ProgressTrack(value: total > 0 ? Double(added) / Double(total) : 0)
            }
            
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Forest.Space.m))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Forest.Space.l))
            layout {
                labeled("Current level", value: "JLPT \(level)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                labeled("Last added", value: lastAdded?.formatted(date: .abbreviated, time: .omitted) ?? "Not yet")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Forest.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }
    
    private func labeled(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Forest.inkMuted)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Forest.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AppComposer.shared.makeProfileView()
}
