import Foundation

public struct RecallQuestion: Hashable, Identifiable {
    public let snapshot: ExerciseSnapshot
    public let source: SavedStudyID?
    public let suppliedReading: String?
    public var id: String { snapshot.id }
    public init(snapshot: ExerciseSnapshot, source: SavedStudyID? = nil, suppliedReading: String? = nil) {
        self.snapshot = snapshot; self.source = source; self.suppliedReading = suppliedReading
    }
}
