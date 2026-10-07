public struct PracticeQueue {
    private var ids: [String]
    public private(set) var repeatAttempts = 0

    public init(ids: [String]) {
        var seen = Set<String>()
        self.ids = ids.filter { seen.insert($0).inserted }
    }

    public var currentID: String? { ids.first }
    public var remainingCount: Int { ids.count }

    public mutating func rate(_ rating: RecallRating) {
        guard !ids.isEmpty else { return }
        let current = ids.removeFirst()
        if rating == .again {
            ids.append(current)
            repeatAttempts += 1
        }
    }
}
