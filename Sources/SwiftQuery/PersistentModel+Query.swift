import Foundation
import SwiftData

public extension PersistentModel {
    /// Constructs an empty query over this model type.
    static func query(_ query: Query<Self> = .init()) -> Query<Self> {
        query
    }
}

public extension PersistentModel {
    /// Constructs an empty query over this model type and invokes ``Query/include(_:)`` on that query.
    static func include(_ predicate: Predicate<Self>) -> Query<Self> {
        query().include(predicate)
    }

    /// Constructs an empty query over this model type and invokes ``Query/exclude(_:)`` on that query.
    static func exclude(_ predicate: Predicate<Self>) -> Query<Self> {
        query().exclude(predicate)
    }

    /// Constructs an empty query over this model type and invokes ``Query/subscript(_:)`` on that query.
    static subscript(_ range: Range<Int>) -> Query<Self> {
        get {
            query()[range]
        }
    }
}

public extension PersistentModel {
    /// Constructs an empty query over this model type and invokes ``Query/sortBy(_:order:)`` on that query.
    static func sortBy<Value>(
        _ keyPath: any KeyPath<Self, Value> & Sendable,
        order: SortOrder = .forward
    ) -> Query<Self>
    where Value: Comparable
    {
        query().sortBy(keyPath, order: order)
    }

    /// Constructs an empty query over this model type and invokes ``Query/sortBy(_:order:)`` on that query.
    static func sortBy<Value>(
        _ keyPath: any KeyPath<Self, Value?> & Sendable,
        order: SortOrder = .forward
    ) -> Query<Self>
    where Value: Comparable
    {
        query().sortBy(keyPath, order: order)
    }

    /// Constructs an empty query over this model type and invokes ``Query/sortBy(_:comparator:order:)`` on that query.
    static func sortBy(
        _ keyPath: any KeyPath<Self, String> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) -> Query<Self> {
        query().sortBy(keyPath, comparator: comparator, order: order)
    }

    /// Constructs an empty query over this model type and invokes ``Query/sortBy(_:comparator:order:)`` on that query.
    static func sortBy(
        _ keyPath: any KeyPath<Self, String?> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) -> Query<Self> {
        query().sortBy(keyPath, comparator: comparator, order: order)
    }
}

public extension PersistentModel {
    /// Constructs an empty query over this model type and invokes ``Query/prefetchRelationships(_:)`` on that query.
    static func prefetchRelationships(_ keyPaths: PartialKeyPath<Self>...) -> Query<Self> {
        query().prefetchRelationships(keyPaths)
    }

    /// Constructs an empty query over this model type and invokes ``Query/fetchKeyPaths(_:)`` on that query.
    static func fetchKeyPaths(_ keyPaths: PartialKeyPath<Self>...) -> Query<Self> {
        query().fetchKeyPaths(keyPaths)
    }
}
