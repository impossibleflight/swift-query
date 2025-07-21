import Foundation
import SwiftData

public extension Query {
    /// Returns the first object matching the query, or `nil` if no matches are found
    /// from within a model actor's isolation context.
    ///
    /// - Parameter isolation: The model actor to execute the query within. Defaults to `#isolation`
    ///   which infers the current actor context.
    /// - Returns: The first matching object, or `nil` if no matches found
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// // Using inferred isolation
    /// @ModelActor
    /// actor DataActor {
    ///     func getYoungest() throws -> Person? {
    ///         try Person.sortBy(\.age).first() // Uses #isolation automatically
    ///     }
    /// }
    ///
    /// // Using explicit actor
    /// let actor = QueryActor(modelContainer: container)
    /// await actor.perform { _ in
    ///     let youngest = try Person.sortBy(\.age).first()
    ///     print("Youngest person: \(youngest?.name ?? "None")")
    /// }
    /// ```
    ///
    /// - SeeAlso: `first(in:)`
    func first(isolation: isolated (any ModelActor) = #isolation) throws -> T? {
        var descriptor = fetchDescriptor
        descriptor.fetchLimit = 1
        let result = try isolation.modelContext.fetch(descriptor)
        return result.first
    }

    /// Returns the last object matching the query, or `nil` if no matches are found
    /// from within a model actor's isolation context.
    ///
    /// - Parameter isolation: The model actor to execute the query within. Defaults to `#isolation`
    ///   which infers the current actor context.
    /// - Returns: The last matching object, or `nil` if no matches found
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// // Get the oldest person concurrently
    /// await container.queryActor().perform { _ in
    ///     let oldest = try Person.sortBy(\.age).last()
    ///     print("Oldest person: \(oldest?.name ?? "None")")
    /// }
    /// ```
    ///
    /// - SeeAlso: `last(in:)`
    func last(isolation: isolated (any ModelActor) = #isolation) throws -> T? {
        try reverse().first(isolation: isolation)
    }

    /// Returns all objects matching the query from within a model actor's isolation
    /// context.
    ///
    /// - Parameter isolation: The model actor to execute the query within. Defaults to `#isolation`
    ///   which infers the current actor context.
    /// - Returns: Array of all matching objects
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// // Fetch all adults concurrently
    /// await container.queryActor().perform { _ in
    ///     let adults = try Person.include(#Predicate { $0.age >= 18 }).results()
    ///     print("Found \(adults.count) adults")
    /// }
    /// ```
    ///
    /// - SeeAlso: `results(in:)`
    func results(isolation: isolated (any ModelActor) = #isolation) throws -> [T] {
        try isolation.modelContext.fetch(fetchDescriptor)
    }

    /// Provides access to a lazily-evaluated collection of objects matching the
    /// query via a closure from within a model actor's isolation context.
    ///
    /// - Parameters:
    ///   - batchSize: Number of objects to fetch per batch. Defaults to 20.
    ///   - isolation: The model actor to execute the query within. Defaults to `#isolation`
    ///     which infers the current actor context.
    ///   - operation: A closure that receives the `FetchResultsCollection` for processing within
    ///     the actor's isolation domain.
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// // Process large result set in batches concurrently
    /// await container.queryActor().perform { _ in
    ///     try Person.sortBy(\.name).fetchedResults(batchSize: 50) { results in
    ///         for person in results.prefix(100) {
    ///             // Process first 100 results efficiently
    ///             print(person.name)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - SeeAlso: `fetchedResults(in:batchSize:)`
    func fetchedResults(
        batchSize: Int = 20,
        isolation: isolated (any ModelActor) = #isolation,
        operation: @Sendable (FetchResultsCollection<T>) -> Void
    ) throws {
        var descriptor = fetchDescriptor
        descriptor.includePendingChanges = false
        let results = try isolation.modelContext.fetch(descriptor, batchSize: batchSize)
        operation(results)
    }

    /// Returns a value computed from a lazily-evaluated collection of objects
    /// matching the query from within a model actor's isolation context.
    ///
    /// - Parameters:
    ///   - batchSize: Number of objects to fetch per batch. Defaults to 20.
    ///   - isolation: The model actor to execute the query within. Defaults to `#isolation`
    ///     which infers the current actor context.
    ///   - operation: A closure that receives the `FetchResultsCollection` and returns a sendable value.
    /// - Returns: The value returned by the operation closure
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// // Get count of large result set efficiently
    /// let count = try await container.queryActor().perform { _ in
    ///     try Person.sortBy(\.name).fetchedResults { results in
    ///         results.count
    ///     }
    /// }
    /// ```
    func fetchedResults<Value>(
        batchSize: Int = 20,
        isolation: isolated (any ModelActor) = #isolation,
        operation: @Sendable (FetchResultsCollection<T>) -> Value
    ) throws -> Value where Value: Sendable {
        var descriptor = fetchDescriptor
        descriptor.includePendingChanges = false
        let results = try isolation.modelContext.fetch(descriptor, batchSize: batchSize)
        return operation(results)
    }

    /// Returns the number of objects matching the query from within a model actor's
    /// isolation context.
    ///
    /// - Parameter isolation: The model actor to execute the query within. Defaults to `#isolation`
    ///   which infers the current actor context.
    /// - Returns: The count of matching objects
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// // Count adults concurrently
    /// let adultCount = try await container.queryActor().perform { _ in
    ///     try Person.include(#Predicate { $0.age >= 18 }).count()
    /// }
    /// ```
    ///
    /// - SeeAlso: `count(in:)`
    func count(isolation: isolated (any ModelActor) = #isolation) throws -> Int {
        try isolation.modelContext.fetchCount(fetchDescriptor)
    }

    /// Returns whether the query has any matching objects within a model actor's
    /// isolation context.
    ///
    /// - Parameter isolation: The model actor to execute the query within. Defaults to `#isolation`
    ///   which infers the current actor context.
    /// - Returns: `true` if no objects match the query, `false` otherwise
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// // Check if any minors exist concurrently
    /// let hasMinors = try await container.queryActor().perform { _ in
    ///     try !Person.include(#Predicate { $0.age < 18 }).isEmpty()
    /// }
    /// ```
    ///
    /// - SeeAlso: `isEmpty(in:)`
    func isEmpty(isolation: isolated (any ModelActor) = #isolation) throws -> Bool {
        try count(isolation: isolation) < 1
    }

    /// Finds an existing object matching the query, or creates a new one if none exists,
    /// then operates on it from within a model actor's isolation context.
    ///
    /// - Parameters:
    ///   - isolation: The model actor to execute the query within. Defaults to `#isolation`
    ///     which infers the current actor context.
    ///   - body: Closure that creates a new object if none is found
    ///   - operation: Closure that operates on the found or created object
    /// - Throws: `Error.missingPredicate` if the query has no predicate, or SwiftData errors
    ///
    /// ## Example
    /// ```swift
    /// // Find or create admin user concurrently
    /// try await container.queryActor().perform { actor in
    ///     try Person
    ///         .include(#Predicate { $0.role == "admin" })
    ///         .findOrCreate(
    ///             body: { Person(name: "Administrator", role: "admin") },
    ///             operation: { admin in
    ///                 print("Admin user: \(admin.name)")
    ///             }
    ///         )
    /// }
    /// ```
    ///
    /// - SeeAlso: `findOrCreate(in:body:)`
    func findOrCreate(
        isolation: isolated (any ModelActor) = #isolation,
        body: () -> T,
        operation: (T) -> Void,
    ) throws {
        guard predicate != nil else {
            throw Error.missingPredicate
        }
        if let found = try first() {
            operation(found)
        } else {
            let created = body()
            isolation.modelContext.insert(created)
            operation(created)
        }
    }

    /// Deletes all objects matching the query from within a model actor's isolation
    /// context.
    ///
    /// - Parameter isolation: The model actor to execute the query within. Defaults to `#isolation`
    ///   which infers the current actor context.
    /// - Throws: any SwiftData errors thrown during query execution
    ///
    /// ## Example
    /// ```swift
    /// // Delete inactive users concurrently
    /// await container.queryActor().perform { _ in
    ///     try Person.include(#Predicate { $0.isInactive }).delete()
    /// }
    /// ```
    ///
    /// - SeeAlso: `delete(in:)`
    func delete(isolation: isolated (any ModelActor) = #isolation) throws {
        let results = try results()
        for object in results {
            isolation.modelContext.delete(object)
        }
    }
}
