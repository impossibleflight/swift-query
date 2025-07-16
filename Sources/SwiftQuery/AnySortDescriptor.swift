import Foundation

/// A workaround for not being able to safely reverse a `SortDescriptor`
/// (filed: FB18433460, changing the value of .order has no effect)
/// The interface is meant to be compatible with `SortDescriptor` while retaining
/// the ability to access the full key path so we can create a reverse descriptor
/// dynamically.
public struct AnySortDescriptor<Compared> {
    public var order: SortOrder = .forward
    public let builder: (SortOrder) -> SortDescriptor<Compared>

    internal var sortDescriptor: SortDescriptor<Compared> {
        builder(order)
    }

    public init<Value>(
        _ keyPath: any KeyPath<Compared, Value> & Sendable,
        order: SortOrder
    )
    where Value: Comparable
    {
        self.order = order
        builder = { SortDescriptor<Compared>(keyPath, order: $0) }
    }

    public init<Value>(
        _ keyPath: any KeyPath<Compared, Value?> & Sendable,
        order: SortOrder
    )
    where Value : Comparable
    {
        self.order = order
        builder = { SortDescriptor<Compared>(keyPath, order: $0) }
    }


    public init(
        _ keyPath: any KeyPath<Compared, String> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) {
        self.order = order
        builder = { SortDescriptor<Compared>(keyPath, comparator: comparator, order: $0) }
    }

    public init(
        _ keyPath: any KeyPath<Compared, String?> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) {
        self.order = order
        builder = { SortDescriptor<Compared>(keyPath, comparator: comparator, order: $0) }
    }
}

package extension AnySortDescriptor {
    func reversed() -> Self {
        var clone = self
        clone.order = switch clone.order {
        case .forward: .reverse
        case .reverse: .forward
        }
        return clone
    }
}
