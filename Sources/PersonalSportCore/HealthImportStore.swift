import Foundation

public struct HealthImportStore: Sendable {
    public init() {}

    public func merge(existing: [ImportedActivity], incoming: [ImportedActivity]) -> [ImportedActivity] {
        var seen = Set(existing.map(\.externalIdentifier))
        var merged = existing
        for activity in incoming where !seen.contains(activity.externalIdentifier) {
            merged.append(activity)
            seen.insert(activity.externalIdentifier)
        }
        return merged.sorted { $0.start < $1.start }
    }
}
