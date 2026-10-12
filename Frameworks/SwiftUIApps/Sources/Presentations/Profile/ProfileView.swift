import SwiftUI

public struct ProfileView: View {
    @EnvironmentObject var appTabs: AppTabsViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var viewModel: ProfileViewModel

    public init(viewModel: ProfileViewModel) { self.viewModel = viewModel }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                HStack(alignment: .top) {
                    ScreenHeader(title: "Progress")
                    Spacer()
                    Button { router.push(.progressSettings, hideNavBar: false) } label: {
                        Image(systemName: "gearshape").font(.system(size: 20))
                            .frame(width: 44, height: 44)

                    }.buttonStyle(.plain).accessibilityLabel("Settings")
                }
                ProgressWeekOverview(viewModel: AppComposer.shared.makeLearningProgressViewModel())
                VStack(alignment: .leading, spacing: Forest.Space.m) {
                    Text("Your collection").font(.title2.weight(.semibold))
                    switch viewModel.state.loadState {
                    case .loading: ProgressView("Loading your collection")
                    case .failed:
                        StateMessage(title: "Couldn't load your collection", message: "Your saved progress or the bundled lists didn't load.", actionTitle: "Try again", action: { viewModel.send(.onAppear) })
                    case .loaded:
                        if let progress = viewModel.state.progress {
                            VStack(spacing: 0) {
                                collectionRow("Words", count: progress.kotobaProgress, total: viewModel.state.totalKotoba, level: progress.kotobaLevel.rawValue, date: progress.kotobaProgress > 0 ? progress.lastKotobaUpdated : nil)
                                Divider().overlay(Forest.line)
                                collectionRow("Kanji", count: progress.kanjiProgress, total: viewModel.state.totalKanji, level: progress.kanjiLevel.rawValue, date: progress.kanjiProgress > 0 ? progress.lastKanjiUpdated : nil)
                            }.background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
                            if progress.kotobaProgress == 0 && progress.kanjiProgress == 0 {
                                Button("Add your first item on Today") { appTabs.appTab = .home }
                                    .buttonStyle(.plain).frame(minHeight: 44)
                            }
                        }
                    }
                }
                VStack(spacing: 0) {
                    ForestNavigationRow(title: "Weekly recap") { router.push(.weeklyRecap, hideNavBar: false) }
                    Divider().overlay(Forest.line)
                    ForestNavigationRow(title: "Activity details") { router.push(.activityDetails, hideNavBar: false) }
                }.background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
            }.padding(.horizontal, Forest.Space.l).padding(.top, Forest.Space.s).padding(.bottom, Forest.Space.xl)
        }.background(Forest.canvas).foregroundStyle(Forest.ink).tint(Forest.moss)
            .onAppear { viewModel.send(.onAppear) }
    }

    private func collectionRow(_ title: String, count: Int, total: Int, level: String, date: Date?) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: Forest.Space.s) {
                Text("Last added: " + (date?.formatted(date: .abbreviated, time: .omitted) ?? "Not yet"))
                Text(title == "Words" ? "Current study list: \(total.formatted()) words" : "Bundled list: \(total.formatted()) kanji")
                if title == "Words" { Text("Includes preserved words from older lists.") }
                else { ProgressTrack(value: total > 0 ? Double(count) / Double(total) : 0) }
            }.font(.subheadline).foregroundStyle(Forest.inkMuted).padding(.top, Forest.Space.s)
        } label: {
            HStack(alignment: .center, spacing: Forest.Space.m) {
                VStack(alignment: .leading, spacing: Forest.Space.xs) {
                    Text(title).font(.headline)
                    Text("Current level: \(level)").font(.subheadline).foregroundStyle(Forest.inkMuted)
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Forest.Space.s)
                Text(count.formatted()).font(.title2.weight(.semibold)).monospacedDigit()
            }

        }.tint(Forest.inkMuted).padding(.horizontal, Forest.Space.l).padding(.vertical, Forest.Space.m).frame(minHeight: 44)
    }
}

struct ProgressSettingsView: View {
    @EnvironmentObject private var router: AppRouter
    @AppStorage("contextualWordReviews") private var contextualWordReviews = false
    var body: some View {
        List {
            Section("Practice") {
                ForestNavigationRow(title: "Daily practice goal") { router.push(.dailyGoal, hideNavBar: false) }.listRowInsets(EdgeInsets())
                Toggle("Sentence context", isOn: $contextualWordReviews)
                Text("Use matching sentences in word-only reviews.").font(.footnote).foregroundStyle(Forest.inkMuted)
            }.listRowBackground(Forest.surface)
            Section("Your data") {
                ForestNavigationRow(title: "Backup and restore") { router.push(.backup, hideNavBar: false) }.listRowInsets(EdgeInsets())
                ForestNavigationRow(title: "Sources") { router.push(.sources, hideNavBar: false) }.listRowInsets(EdgeInsets())
            }.listRowBackground(Forest.surface)
            if let recovery = AppComposer.shared.backupRestoreStatus.recoveryURL {
                Section("Backup restored") {
                    Text("Your learner data was replaced. Keep the recovery backup for a copy of your previous data.")
                    ShareLink("Share recovery backup", item: recovery).frame(minHeight: 44)
                }.listRowBackground(Forest.surface)
            }
            Section {
                Text("Everything is saved on this iPhone. Deleting the app deletes your data. Keep a backup before removing it.").font(.footnote).foregroundStyle(Forest.inkMuted)
            }.listRowBackground(Forest.surface)
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Forest.canvas)
            .foregroundStyle(Forest.ink).tint(Forest.moss).navigationTitle("Settings").toolbar(.visible, for: .navigationBar)
    }
}
