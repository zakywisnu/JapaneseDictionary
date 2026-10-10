import XCTest
import DataKit
@testable import SwiftUIApps

final class KanaPracticeTests: XCTestCase {
    func testFailedSaveNeverStartsPhantomSessionAndRetainsSelectionForRetry() {
        enum Failure: Error { case injected }
        var fail = true
        let model = KanaPracticeViewModel(save: { entries in
            if fail { throw Failure.injected }
            return entries.map { $0.material() }
        })
        model.send(.load)
        model.send(.toggle(KanaCatalog.entries[0].id))
        model.send(.saveAndPractice)
        XCTAssertNil(model.state.session)
        XCTAssertNotNil(model.state.saveError)
        XCTAssertEqual(model.state.selected.count, 1)
        fail = false
        model.send(.saveAndPractice)
        XCTAssertNil(model.state.saveError)
        XCTAssertEqual(model.state.session?.items.count, 1)
        XCTAssertEqual(model.state.session?.items.first?.compositeID.kind, .customCard)
    }
    func testFiltersRetainExplicitCrossGroupSelection() {
        let model = KanaPracticeViewModel(save: { $0.map { $0.material() } })
        model.send(.load); model.send(.selectVisible)
        XCTAssertEqual(model.selectedEntries.count, 46)
        model.send(.script(.katakana)); model.send(.group(.contracted))
        XCTAssertEqual(model.visible.count, 33)
        XCTAssertEqual(model.selectedEntries.count, 46)
        model.send(.selectVisible)
        XCTAssertEqual(model.selectedEntries.count, 79)
    }
    func testCatalogFailureHasRetryState() {
        enum Failure: Error { case injected }
        var fail = true
        let model = KanaPracticeViewModel(load: {
            if fail { throw Failure.injected }; return KanaCatalog.entries
        }, save: { $0.map { $0.material() } })
        model.send(.load)
        XCTAssertFalse(model.state.isLoading); XCTAssertNotNil(model.state.error)
        fail = false; model.send(.load)
        XCTAssertNil(model.state.error); XCTAssertFalse(model.visible.isEmpty)
    }
}
