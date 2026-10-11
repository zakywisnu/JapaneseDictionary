import SwiftUI
import DataKit
import DomainKit

struct WeeklyRecapRouteView: View {
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        AppComposer.shared.makeWeeklyRecapView(availableTopics: {
            let questions = try AppliedPracticeCatalogRepository.bundled().activities.flatMap(\.questions)
            return Dictionary(questions.compactMap { question in question.metadata.map { ($0.topicID, question.questionKind) } }, uniquingKeysWith: { first, _ in first })
        }, onFocus: { focus in
            switch focus {
            case .topic(let kind, let id):
                switch kind {
                case .conjugation: router.push(.conjugationPractice(id), hideNavBar: false)
                case .sentenceOrder: router.push(.sentenceBuilding(id), hideNavBar: false)
                case .listeningComprehension: router.push(.listeningComprehension(id), hideNavBar: false)
                default: router.push(.mistakeReview, hideNavBar: false)
                }
            case .mistakes: router.push(.mistakeReview, hideNavBar: false)
            case .starterPath: router.push(.learningPath, hideNavBar: false)
            case .practice: router.push(.learningPractice, hideNavBar: false)
            }
        })
    }
}
