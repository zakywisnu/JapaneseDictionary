//
//  AppRoutes.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 16/05/25.
//

import SwiftUI
import DataKit
import DomainKit
import ZeroCoreKit

public enum AppRoutes: @preconcurrency Routable {
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
    case dictionaryEntry(String, PassageContext? = nil)
    case conjugationPractice(String? = nil)
    case conjugationWord(String)
    case sentenceBuilding(String? = nil)
    case sentenceBuildingSession([ExerciseSnapshot], String, String)
    case listeningComprehension(String? = nil)
    case listeningComprehensionSession([ExerciseSnapshot], String, String)
    case progressSettings
    case activityDetails
    case weeklyRecap
    case practiceSkill(PracticeSkill)
    case learningPractice
    case kanaPractice
    case speaking(SpeakingTarget)
    case speakingPractice
    case typedPractice
    case listeningPractice
    case exerciseResume(String)
    case learningPath
    case learningStep(String)
    case exerciseHistory
    case mistakeReview
    case grammarExercises
    case readingPractice
    case readingPassage(String)
    case readingVocabulary(String, PassageContext? = nil)
    case readingQuestions(String)
    case dailyStudyPlan
    case lessons
    case material(StudyMaterial, saved: Bool)
    
    @MainActor @ViewBuilder
    public func view() -> some View {
        switch self {
        case .conjugationWord(let lemma):
            AppComposer.shared.makeConjugationPracticeView(lemma: lemma)
        case .conjugationPractice(let topic):
            AppComposer.shared.makeConjugationPracticeView(topicID: topic)
        case .sentenceBuilding(let topic):
            AppComposer.shared.makeSentenceBuildingView(topicID: topic)
        case let .sentenceBuildingSession(snapshots, key, title):
            AppComposer.shared.makeSentenceBuildingSessionView(snapshots: snapshots, activityKey: key, title: title)
        case .listeningComprehension(let topic):
            AppComposer.shared.makeListeningComprehensionView(topicID: topic)
        case let .listeningComprehensionSession(snapshots, key, title):
            AppComposer.shared.makeListeningComprehensionSessionView(snapshots: snapshots, activityKey: key, title: title)
        case .progressSettings:
            ProgressSettingsView()
        case .activityDetails:
            AppComposer.shared.makeLearningProgressView()
        case .weeklyRecap:
            WeeklyRecapRouteView()
        case .practiceSkill(let skill):
            PracticeSkillView(skill: skill)
        case .learningPractice:
            LearningPracticeView()
        case .kanaPractice:
            AppComposer.shared.makeKanaPracticeView()
        case .speaking(let target):
            AppComposer.shared.makeSpeakingView(target: target)
        case .speakingPractice:
            AppComposer.shared.makeSpeakingPracticeView()
        case .typedPractice:
            AppComposer.shared.makeTypedPracticeView()
        case .listeningPractice:
            AppComposer.shared.makeListeningPracticeView()
        case .exerciseResume(let key):
            AppComposer.shared.makeExerciseResumeView(activityKey: key)
        case .learningPath:
            AppComposer.shared.makeLearningPathView()
        case .learningStep(let id):
            AppComposer.shared.makeLearningStepView(id: id)
        case .exerciseHistory:
            AppComposer.shared.makeExerciseHistoryView()
        case .mistakeReview:
            AppComposer.shared.makeMistakeReviewView()
        case .grammarExercises:
            AppComposer.shared.makeGrammarExercisesView()
        case .readingPassage(let id):
            AppComposer.shared.makeReadingPassageView(id: id)
        case .readingVocabulary(let query, let context):
            AppComposer.shared.makeReadingVocabularyView(query: query, passageContext: context)
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
        case let .dictionaryEntry(id, context):
            AppComposer.shared.makeDictionaryBrowseDetailView(catalogID: id, passageContext: context)
        }
    }
}
