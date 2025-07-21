import Foundation

/// A type-erased sort descriptor that preserves the full key path in order to
/// support order reversal. This is necessary to work around a bug in `SortDescriptor`
/// where changing the `order` property has no effect on actual sorting behavior
/// using the descriptor (FB18433460).
///
/// ## Usage
///
/// ```swift
/// // Create sort descriptors
/// let nameSort = AnySortDescriptor<Person>(\.name, order: .forward)
/// let ageSort = AnySortDescriptor<Person>(\.age, order: .reverse)
///
/// // Reverse sort order reliably
/// let reversedNameSort = nameSort.reversed()
/// ```
///
/// - Note: This type is primarily used internally by `Query`. Most users should use
///   the `Query.sortBy()` methods instead of creating `AnySortDescriptor` instances directly.
public struct AnySortDescriptor<Compared> {
    /// The current sort order for this descriptor.
    public var order: SortOrder = .forward
    
    /// Function that creates `SortDescriptor` instances with the specified order.
    public let builder: (SortOrder) -> SortDescriptor<Compared>

    internal var sortDescriptor: SortDescriptor<Compared> {
        builder(order)
    }

    /// Creates a sort descriptor for a comparable property.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to the property to sort by
    ///   - order: Sort order (forward or reverse)
    public init<Value>(
        _ keyPath: any KeyPath<Compared, Value> & Sendable,
        order: SortOrder
    )
    where Value: Comparable
    {
        self.order = order
        builder = { SortDescriptor<Compared>(keyPath, order: $0) }
    }

    /// Creates a sort descriptor for an optional comparable property.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to the optional property to sort by
    ///   - order: Sort order (forward or reverse)
    public init<Value>(
        _ keyPath: any KeyPath<Compared, Value?> & Sendable,
        order: SortOrder
    )
    where Value : Comparable
    {
        self.order = order
        builder = { SortDescriptor<Compared>(keyPath, order: $0) }
    }

    /// Creates a sort descriptor for a String property with custom comparison.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to the String property to sort by
    ///   - comparator: String comparison method. Defaults to localized standard.
    ///   - order: Sort order (forward or reverse). Defaults to forward.
    public init(
        _ keyPath: any KeyPath<Compared, String> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) {
        self.order = order
        builder = { SortDescriptor<Compared>(keyPath, comparator: comparator, order: $0) }
    }

    /// Creates a sort descriptor for an optional String property with custom comparison.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to the optional String property to sort by
    ///   - comparator: String comparison method. Defaults to localized standard.
    ///   - order: Sort order (forward or reverse). Defaults to forward.
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
