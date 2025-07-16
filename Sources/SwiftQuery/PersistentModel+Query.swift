import Foundation
import SwiftData

extension PersistentModel {
    static func include(_ predicate: Predicate<Self>) -> Query<Self> {
        query().include(predicate)
    }

    static func exclude(_ predicate: Predicate<Self>) -> Query<Self> {
        query().exclude(predicate)
    }

    static func query(_ query: Query<Self> = .init()) -> Query<Self> {
        query
    }

    static subscript(_ range: Range<Int>) -> Query<Self> {
        get {
            query()[range]
        }
    }
}

public extension PersistentModel {
    static func sortBy<Value>(
        _ keyPath: any KeyPath<Self, Value> & Sendable,
        order: SortOrder = .forward
    ) -> Query<Self>
    where Value: Comparable
    {
        query().sortBy(keyPath, order: order)
    }

    static func sortBy<Value>(
        _ keyPath: any KeyPath<Self, Value?> & Sendable,
        order: SortOrder = .forward
    ) -> Query<Self>
    where Value: Comparable
    {
        query().sortBy(keyPath, order: order)
    }


    static func sortBy(
        _ keyPath: any KeyPath<Self, String> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) -> Query<Self> {
        query().sortBy(keyPath, comparator: comparator, order: order)
    }

    static func sortBy(
        _ keyPath: any KeyPath<Self, String?> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) -> Query<Self> {
        query().sortBy(keyPath, comparator: comparator, order: order)
    }
}
