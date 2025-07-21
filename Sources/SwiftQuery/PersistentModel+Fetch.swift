import SwiftData

@MainActor
extension PersistentModel {
    /// Builds a query over this model type and invokes ``Query/results(in:)`` on that query.
    static func results(in container: ModelContainer) throws -> [Self] {
        try query().results(in: container)
    }

    /// Builds a query over this model type and invokes ``Query/fetchedResults(in:)`` on that query.
    static func fetchedResults(in container: ModelContainer) throws -> FetchResultsCollection<Self> {
        try query().fetchedResults(in: container)
    }

    /// Builds a query over this model type and invokes ``Query/fetchedResults(in:batchSize:)`` on that query.
    static func fetchedResults(in container: ModelContainer, batchSize: Int) throws -> FetchResultsCollection<Self> {
        try query().fetchedResults(in: container, batchSize: batchSize)
    }

    /// Builds a query over this model type and invokes ``Query/count(in:)`` on that query.
    static func count(in container: ModelContainer) throws -> Int {
        try query().count(in: container)
    }

    /// Builds a query over this model type and invokes ``Query/isEmpty(in:)`` on that query.
    static func isEmpty(in container: ModelContainer) throws -> Bool {
        try query().isEmpty(in: container)
    }

    /// Builds a query over this model type and invokes ``Query/findOrCreate(in:body:)`` on that query.
    static func findOrCreate(
        in container: ModelContainer,
        body: () -> Self
    ) throws -> Self {
        try query().findOrCreate(in: container, body: body)
    }
}

extension PersistentModel {
    /// Builds a query over this model type and invokes ``Query/results(isolation:)`` on that query.
    static func results(isolation: isolated (any ModelActor) = #isolation) throws -> [Self] {
        try query().results()
    }

    /// Builds a query over this model type and invokes ``Query/fetchedResults(isolation:operation:)`` on that query.
    static func fetchedResults(
        isolation: isolated (any ModelActor) = #isolation,
        operation: @Sendable (FetchResultsCollection<Self>) -> Void
    ) throws  {
        try query().fetchedResults(operation: operation)
    }

    /// Builds a query over this model type and invokes ``Query/fetchedResults(batchSize:isolation:operation:)`` on that query.
    static func fetchedResults(
        batchSize: Int,
        isolation: isolated (any ModelActor) = #isolation,
        operation: @Sendable (FetchResultsCollection<Self>) -> Void
    ) throws {
        try query().fetchedResults(batchSize: batchSize, operation: operation)
    }

    /// Builds a query over this model type and invokes ``Query/fetchedResults(isolation:operation:)`` on that query.
    static func fetchedResults<Value>(
        isolation: isolated (any ModelActor) = #isolation,
        operation: @Sendable (FetchResultsCollection<Self>) -> Value
    ) throws -> Value where Value: Sendable {
        try query().fetchedResults(operation: operation)
    }

    /// Builds a query over this model type and invokes ``Query/fetchedResults(batchSize:isolation:operation:)`` on that query.
    static func fetchedResults<Value>(
        batchSize: Int,
        isolation: isolated (any ModelActor) = #isolation,
        operation: @Sendable (FetchResultsCollection<Self>) -> Value
    ) throws -> Value where Value: Sendable {
        try query().fetchedResults(batchSize: batchSize, operation: operation)
    }

    /// Builds a query over this model type and invokes ``Query/count(isolation:)`` on that query.
    static func count(isolation: isolated (any ModelActor) = #isolation) throws -> Int {
        try query().count()
    }

    /// Builds a query over this model type and invokes ``Query/isEmpty(isolation:)`` on that query.
    static func isEmpty(isolation: isolated (any ModelActor) = #isolation) throws -> Bool {
        try query().isEmpty()
    }

    /// Builds a query over this model type and invokes ``Query/findOrCreate(isolation:body:operation:)`` on that query.
    static func findOrCreate(
        isolation: isolated (any ModelActor) = #isolation,
        body: () -> Self,
        operation: (Self) -> Void
    ) throws {
        try query().findOrCreate(body: body, operation: operation)
    }
}
