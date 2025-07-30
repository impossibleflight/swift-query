import Foundation
import SwiftData

@MainActor
public extension Query {
    /// Returns the first object matching the query, or `nil` if no matches are found.
    ///
    /// - Parameter container: The model container to execute the query against
    /// - Returns: The first matching object, or `nil` if no matches found
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// let youngest = try Person.sortBy(\.age).first(in: container)
    /// ```
    func first(in container: ModelContainer) throws -> T? {
        var descriptor = self
        descriptor.range = 0..<1
        let result = try container.mainContext.fetch(fetchDescriptor)
        return result.first
    }

    /// Returns the last object matching the query, or `nil` if no matches are found.
    ///
    /// - Parameter container: The model container to execute the query against
    /// - Returns: The last matching object, or `nil` if no matches found
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// let oldest = try Person.sortBy(\.age).last(in: container)
    /// ```
    func last(in container: ModelContainer) throws -> T? {
        try reverse().first(in: container)
    }

    /// Returns all objects matching the query.
    ///
    /// - Parameter container: The model container to execute the query against
    /// - Returns: Array of all matching objects
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// let adults = try Person.include(#Predicate { $0.age >= 18 }).results(in: container)
    /// ```
    func results(in container: ModelContainer) throws -> [T] {
        try container.mainContext.fetch(fetchDescriptor)
    }

    /// Returns a lazily-evaluated collection of objects matching the query.
    ///
    /// Use this method when working with large result sets that you don't need
    /// to load entirely into memory at once.
    ///
    /// - Parameters:
    ///   - container: The model container to execute the query against
    ///   - batchSize: Number of objects to fetch per batch. Defaults to 20.
    /// - Returns: A `FetchResultsCollection` that loads results on-demand
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// let lazyResults = try Person.sortBy(\.name).fetchedResults(in: container)
    /// for person in lazyResults.prefix(100) {
    ///     // Process first 100 results without loading everything
    /// }
    /// ```
    func fetchedResults(
        in container: ModelContainer,
        batchSize: Int = 20
    ) throws -> FetchResultsCollection<T> {
        var descriptor = fetchDescriptor
        descriptor.includePendingChanges = false
        return try container.mainContext.fetch(descriptor, batchSize: batchSize)
    }

    /// Returns the number of objects matching the query.
    ///
    /// - Parameter container: The model container to execute the query against
    /// - Returns: The count of matching objects
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// let adultCount = try Person.include(#Predicate { $0.age >= 18 }).count(in: container)
    /// ```
    func count(in container: ModelContainer) throws -> Int {
        try container.mainContext.fetchCount(fetchDescriptor)
    }

    /// Returns whether the query has any matching objects.
    ///
    /// - Parameter container: The model container to execute the query against
    /// - Returns: `true` if no objects match the query, `false` otherwise
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// let hasMinors = try !Person.include(#Predicate { $0.age < 18 }).isEmpty(in: container)
    /// ```
    func isEmpty(in container: ModelContainer) throws -> Bool {
        try count(in: container) < 1
    }

    /// Finds the first object matching the query, or creates a new one if none exists.
    ///
    /// - Parameters:
    ///   - container: The model container to execute the query against
    ///   - body: Closure that creates a new object if none is found
    /// - Returns: Either the found existing object or the newly created one
    /// - Throws: `Error.missingPredicate` if the query has no predicate, or SwiftData errors
    ///
    /// ## Example
    /// ```swift
    /// let admin = try Person
    ///     .include(#Predicate { $0.role == "admin" })
    ///     .findOrCreate(in: container) {
    ///         Person(name: "Administrator", role: "admin")
    ///     }
    /// ```
    func findOrCreate(
        in container: ModelContainer,
        body: () -> T
    ) throws -> T {
        guard let found = try first(in: container) else {
            let created = body()
            container.mainContext.insert(created)
            return created
        }
        return found
    }

    /// Deletes all objects matching the query.
    ///
    /// - Parameter container: The model container to execute the query against
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// try Person.include(#Predicate { $0.isInactive }).delete(in: container)
    /// ```
    func delete(in container: ModelContainer) throws {
        let results = try results(in: container)
        results.forEach {
            container.mainContext.delete($0)
        }
    }
}
