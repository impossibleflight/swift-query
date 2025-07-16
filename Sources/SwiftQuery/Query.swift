import Foundation
import SwiftData

/// <#Description#>
/// - Note: the interface here should be a simple extension on FetchDescriptor,
///         but there is a bug in SortDescriptor that makes reversing one all but
///         impossible (filed: FB18433460), so we store the values we need to
///         reverse them on the fly
public struct Query<T: PersistentModel> {
    public var predicate: Predicate<T>?
    public var sortBy: [AnySortDescriptor<T>]
    public var fetchLimit: Int?
    public var fetchOffset: Int?
    public var includePendingChanges: Bool = false

    public var sortDescriptors: [SortDescriptor<T>] {
        sortBy.map { $0.sortDescriptor }
    }

    package var fetchDescriptor: FetchDescriptor<T> {
        .init(predicate: predicate, sortBy: sortDescriptors)
    }

    public init(
        predicate: Predicate<T>? = nil,
        sortBy: [AnySortDescriptor<T>] = []
    ) {
        self.predicate = predicate
        self.sortBy = sortBy
    }

    public func include(_ predicate: Predicate<T>) -> Self {
        Query(predicate: predicate, sortBy: sortBy)
    }

    public func exclude(_ predicate: Predicate<T>) -> Self {
        let excludePredicate = #Predicate{ item in
            !predicate.evaluate(item)
        }

        return Query(predicate: excludePredicate, sortBy: sortBy)
    }

    public func reverse() -> Self {
        Query(predicate: predicate, sortBy: sortBy.map {
            $0.reversed() }
        )
    }

    public subscript(_ range: Range<Int>) -> Self {
        get {
            var query = Query(predicate: predicate, sortBy: sortBy)
            query.fetchOffset = range.lowerBound
            query.fetchLimit = range.upperBound - range.lowerBound
            return query
        }
    }
}

public extension Query {
    func sortBy<Value>(
        _ keyPath: any KeyPath<T, Value> & Sendable,
        order: SortOrder = .forward
    ) -> Self
    where Value: Comparable
    {
        Query(predicate: predicate, sortBy: sortBy + [.init(keyPath, order: order)])
    }

    func sortBy<Value>(
        _ keyPath: any KeyPath<T, Value?> & Sendable,
        order: SortOrder = .forward
    ) -> Self
    where Value: Comparable
    {
        Query(predicate: predicate, sortBy: sortBy + [.init(keyPath, order: order)])
    }


    func sortBy(
        _ keyPath: any KeyPath<T, String> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) -> Self {
        Query(predicate: predicate, sortBy: sortBy + [.init(keyPath, comparator: comparator, order: order)])
    }

    func sortBy(
        _ keyPath: any KeyPath<T, String?> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) -> Self {
        Query(predicate: predicate, sortBy: sortBy + [.init(keyPath, comparator: comparator, order: order)])
    }
}
