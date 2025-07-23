import Foundation
import SwiftData

/// A model actor used for executing queries concurrently.
@ModelActor
public actor QueryActor: Sendable {
    /// Executes a block of code within this actor's isolation domain for processing models.
    /// 
    /// ## Example
    /// ```swift
    /// await actor.perform { _ in
    ///     let users = Person.include(#Predicate { $0.isActive }).results()
    ///     for user in users {
    ///         user.lastSeen = Date()
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter operation: The code to execute withing the actor's context
    /// - Throws: Any errors thrown by the executed block
    public func perform(
        _ operation: @Sendable (isolated QueryActor) async throws -> Void
    ) async rethrows {
        try await operation(self)
    }

    /// Executes a block of code within this actor's isolation domain and returns the resulting value.
    ///
    /// ## Example
    /// ```swift
    /// let activeCount = await actor.perform { _ in
    ///     Person.include(#Predicate { $0.isActive }).count()
    /// }
    /// ```
    ///
    /// - Parameter operation: The code to execute using within actor's context
    /// - Returns: The result of the executed block
    /// - Throws: Any errors thrown by the executed block
    /// - Note: model instances cannot be returned from the executed block because they are not `Sendable`
    ///
    public func perform<T>(
        _ operation: @Sendable (isolated QueryActor) async throws -> T
    ) async rethrows -> T where T: Sendable {
        try await operation(self)
    }
}

public extension ModelContainer {
    /// Creates a `QueryActor` associated with this model container.
    func createQueryActor() -> QueryActor {
        .init(modelContainer: self)
    }
}
