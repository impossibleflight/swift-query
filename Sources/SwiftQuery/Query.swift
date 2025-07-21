import Foundation
import SwiftData

/// An expressive query language for SwiftData.
///
/// `Query` provides a simple interface for building complex fetch descriptors by chaining
/// refinements like filtering, sorting, and limiting results. The resulting query can be
/// saved for reuse or executed immediately.
///
/// ## Usage
///
/// ```swift
/// // Building a query
/// let adultsQuery = Query<Person>()
///     .include(#Predicate { $0.age >= 18 })
///     .sortBy(\.name)
///
/// // Fetching results
/// let adults = Person
///     .results(in: modelContainer)
///
/// // Fetching results in an isolation context
/// actor MyActor {
///     func fetchAdults() throws {
///         let adults = Person
///             .results()
///     }
/// }
/// ```
///
public struct Query<T: PersistentModel> {
    /// The predicate used to filter results. When `nil`, returns all objects of type `T`.
    public var predicate: Predicate<T>?
    
    /// The sort descriptors that define result ordering. Multiple descriptors are applied in sequence.
    public var sortBy: [AnySortDescriptor<T>]
    
    /// A range representing the number of results to skip before returning matches and maximum number of results to fetch. When `nil`, the query will return all matching results.
    public var range: Range<Int>?

    /// SwiftData compatible sort descriptors generated from the query's sort configuration.
    package var sortDescriptors: [SortDescriptor<T>] {
        sortBy.map { $0.sortDescriptor }
    }

    package var fetchDescriptor: FetchDescriptor<T> {
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: sortDescriptors)
        if let range {
            descriptor.fetchOffset = range.lowerBound
            descriptor.fetchLimit = range.upperBound - range.lowerBound
        }
        return descriptor
    }

    /// Creates a new query with optional filtering and sorting configuration.
    /// 
    /// - Parameters:
    ///   - predicate: Optional predicate to filter results. When `nil`, returns all objects.
    ///   - sortBy: Array of sort descriptors to apply to results. Defaults to no sorting.
    ///   - range: Optional range of results to fetch. When `nil` returns all results.
    public init(
        predicate: Predicate<T>? = nil,
        sortBy: [AnySortDescriptor<T>] = [],
        range: Range<Int>? = nil
    ) {
        self.predicate = predicate
        self.sortBy = sortBy
        self.range = range
    }

    /// Returns a new query that includes only objects matching the given predicate.
    ///
    /// When called on a query that already has a predicate, this creates a compound
    /// predicate using logical AND, combining the existing predicate with the new one.
    ///
    /// - Parameter newPredicate: The predicate to filter results
    /// - Returns: A new query with the compound predicate
    ///
    /// ## Example
    /// ```swift
    /// // Single predicate
    /// let adults = Person.include(#Predicate { $0.age >= 18 })
    ///
    /// // Compound predicate (logical AND)
    /// let adultJacks = Person
    ///     .include(#Predicate { $0.age >= 18 })
    ///     .include(#Predicate { $0.name == "Jack" })
    /// ```
    public func include(_ newPredicate: Predicate<T>) -> Self {
        var compoundPredicate = newPredicate
        if let predicate {
            compoundPredicate = #Predicate {
                predicate.evaluate($0) && newPredicate.evaluate($0)
            }
        }
        return Query(predicate: compoundPredicate, sortBy: sortBy, range: range)
    }

    /// Returns a new query that excludes objects matching the given predicate.
    ///
    /// This creates an inverted predicate and compounds it with any existing predicate
    /// using logical AND. Multiple ``exclude()`` calls create compound exclusions.
    ///
    /// - Parameter predicate: The predicate defining objects to exclude
    /// - Returns: A new query with the compound exclusion predicate
    ///
    /// ## Example
    /// ```swift
    /// // Single exclusion
    /// let nonAdults = Person.exclude(#Predicate { $0.age >= 18 })
    ///
    /// // Compound exclusions (logical AND)
    /// let activeAdults = Person
    ///     .include(#Predicate { $0.age >= 18 })
    ///     .exclude(#Predicate { $0.isInactive })
    ///     .exclude(#Predicate { $0.isBanned })
    /// ```
    public func exclude(_ predicate: Predicate<T>) -> Self {
        let excludePredicate = #Predicate{ item in
            !predicate.evaluate(item)
        }

        return include(excludePredicate)
    }

    /// Returns a new query with all sort orders reversed.
    ///
    /// This reverses the sort order of all existing sort descriptors. Forward becomes reverse
    /// and reverse becomes forward. Useful for toggling sort direction.
    ///
    /// - Returns: A new query with reversed sort orders
    ///
    /// ## Example
    /// ```swift
    /// let oldestFirst = Person.sortBy(\.age).reverse()
    /// ```
    public func reverse() -> Self {
        Query(
            predicate: predicate,
            sortBy: sortBy.map { $0.reversed() },
            range: range
        )
    }

    /// Returns a new query that fetches only objects within the specified range.
    ///
    /// This sets `fetchOffset` and `fetchLimit` to implement pagination. The range
    /// represents indices in the full result set.
    ///
    /// - Parameter range: The range of results to fetch (e.g., `0..<10` for first 10 results)
    /// - Returns: A new query limited to the specified range
    ///
    /// ## Example
    /// ```swift
    /// let firstPage = Person.sortBy(\.name)[0..<20]
    /// let secondPage = Person.sortBy(\.name)[20..<40]
    /// ```
    public subscript(_ range: Range<Int>) -> Self {
        get {
            Query(predicate: predicate, sortBy: sortBy, range: range)
        }
    }
}

public extension Query {
    /// Adds a sort descriptor for a comparable property to the query.
    ///
    /// Multiple sort descriptors are applied in sequence, allowing for complex sorting
    /// like "sort by name, then by age within each name group".
    ///
    /// - Parameters:
    ///   - keyPath: Key path to the property to sort by
    ///   - order: Sort order (forward or reverse). Defaults to forward.
    /// - Returns: A new query with the additional sort descriptor
    ///
    /// ## Example
    /// ```swift
    /// let sorted = Person
    ///     .sortBy(\.name)                    // Sort by name first
    ///     .sortBy(\.age, order: .reverse)    // Then by age (oldest first)
    /// ```
    func sortBy<Value>(
        _ keyPath: any KeyPath<T, Value> & Sendable,
        order: SortOrder = .forward
    ) -> Self
    where Value: Comparable
    {
        Query(predicate: predicate, sortBy: sortBy + [.init(keyPath, order: order)], range: range)
    }

    /// Adds a sort descriptor for an optional comparable property to the query.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to the optional property to sort by
    ///   - order: Sort order (forward or reverse). Defaults to forward.
    /// - Returns: A new query with the additional sort descriptor
    ///
    /// ## Example
    /// ```swift
    /// let sorted = Person.sortBy(\.nickname, order: .forward) // nil values sorted first
    /// ```
    func sortBy<Value>(
        _ keyPath: any KeyPath<T, Value?> & Sendable,
        order: SortOrder = .forward
    ) -> Self
    where Value: Comparable
    {
        Query(predicate: predicate, sortBy: sortBy + [.init(keyPath, order: order)], range: range)
    }

    /// Adds a sort descriptor for a String property with custom comparison.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to the String property to sort by
    ///   - comparator: String comparison method. Defaults to localized standard.
    ///   - order: Sort order (forward or reverse). Defaults to forward.
    /// - Returns: A new query with the additional sort descriptor
    ///
    /// ## Example
    /// ```swift
    /// let sorted = Person.sortBy(\.name, comparator: .lexical, order: .forward)
    /// ```
    func sortBy(
        _ keyPath: any KeyPath<T, String> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) -> Self {
        Query(predicate: predicate, sortBy: sortBy + [.init(keyPath, comparator: comparator, order: order)], range: range)
    }

    /// Adds a sort descriptor for an optional String property with custom comparison.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to the optional String property to sort by
    ///   - comparator: String comparison method. Defaults to localized standard.
    ///   - order: Sort order (forward or reverse). Defaults to forward.
    /// - Returns: A new query with the additional sort descriptor
    ///
    /// ## Example
    /// ```swift
    /// let sorted = Person.sortBy(\.nickname, comparator: .localized, order: .reverse)
    /// ```
    func sortBy(
        _ keyPath: any KeyPath<T, String?> & Sendable,
        comparator: String.StandardComparator = .localizedStandard,
        order: SortOrder = .forward
    ) -> Self {
        Query(predicate: predicate, sortBy: sortBy + [.init(keyPath, comparator: comparator, order: order)], range: range)
    }
}
