import XCTest
import DataKit
@testable import SwiftUIApps

final class ExerciseReadingTests: XCTestCase {
    func testChoosingLocksAnswerAndScoresOnlyOnce() {
        let model = ExerciseSessionViewModel(exercises: Array(ExerciseCatalog.grammar.prefix(2)))
        model.send(.choose(-1))
        XCTAssertNil(model.state.selectedIndex)
        model.send(.choose(0))
        model.send(.choose(1))
        XCTAssertEqual(model.state.selectedIndex, 0)
        XCTAssertEqual(model.state.correctCount, 1)
        XCTAssertEqual(model.state.position, 0)
    }

    func testNextRequiresAnswerAndCompletionRequiresExplicitAction() {
        let exercise = ExerciseCatalog.grammar[0]
        let model = ExerciseSessionViewModel(exercises: [exercise])
        model.send(.next)
        XCTAssertFalse(model.state.isComplete)
        model.send(.choose(1))
        XCTAssertFalse(model.state.isComplete)
        XCTAssertEqual(model.state.correctCount, 0)
        model.send(.next)
        XCTAssertTrue(model.state.isComplete)
        XCTAssertNil(model.current)
        model.send(.choose(0))
        XCTAssertEqual(model.state.correctCount, 0)
        model.send(.restart)
        XCTAssertFalse(model.state.isComplete)
        XCTAssertNil(model.state.selectedIndex)
        XCTAssertEqual(model.state.position, 0)
    }

    func testNextResetsChoiceAndRestartResetsScore() {
        let model = ExerciseSessionViewModel(exercises: Array(ExerciseCatalog.grammar.prefix(2)))
        model.send(.choose(0))
        model.send(.next)
        XCTAssertEqual(model.state.position, 1)
        XCTAssertNil(model.state.selectedIndex)
        model.send(.choose(1))
        XCTAssertEqual(model.state.correctCount, 2)
        model.send(.restart)
        XCTAssertEqual(model.state.correctCount, 0)
        XCTAssertEqual(model.state.total, 2)
        XCTAssertEqual(model.current?.id, ExerciseCatalog.grammar[0].id)
    }

    func testCorpusHasUniqueValidQuestionsAndSubstantialPassages() throws {
        XCTAssertGreaterThanOrEqual(ExerciseCatalog.grammar.count, 15)
        XCTAssertTrue(ExerciseCatalog.grammar.contains { $0.kind == .choice })
        XCTAssertTrue(ExerciseCatalog.grammar.contains { $0.kind == .fillBlank })
        XCTAssertGreaterThanOrEqual(ReadingCatalog.passages.count, 6)
        XCTAssertEqual(Set(ReadingCatalog.passages.map(\.id)).count, ReadingCatalog.passages.count)
        let questions = ExerciseCatalog.grammar + ReadingCatalog.passages.flatMap(\.questions)
        XCTAssertEqual(Set(questions.map(\.id)).count, questions.count)
        XCTAssertTrue(questions.allSatisfy(\.isValid))
        let words = try VocabularyCatalogRepository.bundled().catalog.entries
        let index = DictionarySearchIndex(words: words)
        for passage in ReadingCatalog.passages {
            XCTAssertFalse(passage.reading.isEmpty)
            XCTAssertFalse(passage.translation.isEmpty)
            XCTAssertGreaterThanOrEqual(passage.questions.count, 2)
            for word in passage.vocabulary {
                XCTAssertTrue(passage.text.contains(word))
                XCTAssertFalse(index.results(query: word, level: nil).isEmpty, word)
            }
        }
    }

    func testEmptyAndInvalidExerciseSessionsCannotBeScored() {
        let empty = ExerciseSessionViewModel(exercises: [])
        empty.send(.choose(0))
        empty.send(.next)
        XCTAssertNil(empty.current)
        XCTAssertEqual(empty.state.correctCount, 0)
        let invalid = PracticeExercise(id: "bad", kind: .choice, prompt: "Bad", choices: ["Only"], correctIndex: 1, explanation: "Invalid")
        let model = ExerciseSessionViewModel(exercises: [invalid])
        XCTAssertTrue(model.state.hasInvalidContent)
        XCTAssertNil(model.current)
        model.send(.choose(0))
        XCTAssertNil(model.state.selectedIndex)
    }

    func testReadingFailureRetryAndEmptyStates() {
        enum Failure: Error { case resource }
        var fails = true
        let model = ReadingPracticeViewModel(loadPassages: {
            if fails { throw Failure.resource }
            return ReadingCatalog.passages
        })
        model.send(.load)
        XCTAssertEqual(model.state.loadState, .failed)
        fails = false
        model.send(.retry)
        XCTAssertEqual(model.state.loadState, .loaded)
        XCTAssertEqual(model.state.passages.count, 6)
        let empty = ReadingPracticeViewModel(loadPassages: { [] })
        empty.send(.load)
        XCTAssertEqual(empty.state.loadState, .loaded)
        XCTAssertTrue(empty.state.passages.isEmpty)
    }

    func testReadingAnnotationsAreExplicit() {
        let model = ReadingDetailViewModel()
        XCTAssertFalse(model.state.showsReading)
        XCTAssertFalse(model.state.showsTranslation)
        model.send(.readingChanged(true))
        model.send(.translationChanged(true))
        XCTAssertTrue(model.state.showsReading)
        XCTAssertTrue(model.state.showsTranslation)
        model.send(.readingChanged(false))
        model.send(.translationChanged(false))
        XCTAssertFalse(model.state.showsReading)
        XCTAssertFalse(model.state.showsTranslation)
    }
}
