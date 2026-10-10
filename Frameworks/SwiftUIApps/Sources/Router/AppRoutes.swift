//
//  AppRoutes.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 16/05/25.
//

import SwiftUI
import DataKit
import ZeroCoreKit

public enum AppRoutes: Routable {
    case onboarding
    case splashScreen
    case dashboard
    case detail(DetailViewModel.Config)
    case review(ReviewSession)
    case sources
    case backup
    case studyLists
    case studyList(String)
    case dailyGoal
    case difficult
    case dictionary
    case dictionaryEntry(String)
    case learningPractice
    case kanaPractice
    case grammarExercises
    case readingPractice
    case readingPassage(String)
    case readingVocabulary(String)
    case readingQuestions(String)
    case dailyStudyPlan
    case lessons
    case material(StudyMaterial, saved: Bool)
    
    @ViewBuilder
    public func view() -> some View {
        switch self {
        case .learningPractice:
            LearningPracticeView()
        case .kanaPractice:
            AppComposer.shared.makeKanaPracticeView()
        case .grammarExercises:
            AppComposer.shared.makeGrammarExercisesView()
        case .readingPassage(let id):
            AppComposer.shared.makeReadingPassageView(id: id)
        case .readingVocabulary(let query):
            AppComposer.shared.makeReadingVocabularyView(query: query)
        case .readingQuestions(let id):
            AppComposer.shared.makeReadingQuestionsView(id: id)
        case .readingPractice:
            AppComposer.shared.makeReadingPracticeView()
        case .dailyStudyPlan:
            AppComposer.shared.makeDailyStudyPlanView()
        case .lessons:
            AppComposer.shared.makeLessonsView()
        case let .material(material, saved):
            AppComposer.shared.makeMaterialDetailView(material, saved: saved)
        case .onboarding:
            AppComposer.shared.makeOnboardingView()
        case .splashScreen:
            AppSplashScreen()
        case .dashboard:
            DashboardView()
        case let .detail(config):
            AppComposer.shared.makeDetailView(config)
        case let .review(session):
            AppComposer.shared.makeReviewView(session)
        case .sources:
            SourcesView()
        case .backup:
            AppComposer.shared.makeBackupView()
        case .studyLists:
            AppComposer.shared.makeStudyListsView()
        case let .studyList(id):
            AppComposer.shared.makeStudyListView(id)
        case .difficult:
            AppComposer.shared.makeDifficultPracticeView()
        case .dailyGoal:
            AppComposer.shared.makeDailyGoalSettingsView()
        case .dictionary:
            AppComposer.shared.makeDictionaryBrowseView()
        case let .dictionaryEntry(id):
            AppComposer.shared.makeDictionaryBrowseDetailView(catalogID: id)
        }
    }
}
