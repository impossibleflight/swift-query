import SwiftData

@MainActor
public extension PersistentModel {
    /// Constructs an empty query over this model type and invokes ``Query/first(in:)`` on that query.
    /// This is named `any` rather than `first` because there is no order.
    static func any(in container: ModelContainer) throws -> Self? {
        try query().first(in: container)
    }

    /// Constructs an empty query over this model type and invokes ``Query/results(in:)`` on that query.
    static func results(in container: ModelContainer) throws -> [Self] {
        try query().results(in: container)
    }

    /// Constructs an empty query over this model type and invokes ``Query/fetchedResults(in:)`` on that query.
    static func fetchedResults(in container: ModelContainer) throws -> FetchResultsCollection<Self> {
        try query().fetchedResults(in: container)
    }

    /// Constructs an empty query over this model type and invokes ``Query/fetchedResults(in:batchSize:)`` on that query.
    static func fetchedResults(in container: ModelContainer, batchSize: Int) throws -> FetchResultsCollection<Self> {
        try query().fetchedResults(in: container, batchSize: batchSize)
    }

    /// Constructs an empty query over this model type and invokes ``Query/count(in:)`` on that query.
    static func count(in container: ModelContainer) throws -> Int {
        try query().count(in: container)
    }

    /// Constructs an empty query over this model type and invokes ``Query/isEmpty(in:)`` on that query.
    static func isEmpty(in container: ModelContainer) throws -> Bool {
        try query().isEmpty(in: container)
    }

    /// Constructs an empty query over this model type and invokes ``Query/findOrCreate(in:body:)`` on that query.
    static func findOrCreate(
        in container: ModelContainer,
        body: () -> Self
    ) throws -> Self {
        try query().findOrCreate(in: container, body: body)
    }

    /// Constructs an empty query over this model type and invokes ``Query/delete(in:)`` on that query.
    /// This is named `deleteAll` rather than `delete` to signify with an empty query this will match all objects.
    static func deleteAll(
        in container: ModelContainer
    ) throws {
        try query().delete(in: container)
    }
}

public extension PersistentModel {
    /// Constructs an empty query over this model type and invokes ``Query/first(isolation:)`` on that query.
    /// This is named `any` rather than `first` because there is no order.
    static func any(isolation: isolated (any ModelActor) = #isolation) throws -> Self? {
        try query().first()
    }

    /// Constructs an empty query over this model type and invokes ``Query/results(isolation:)`` on that query.
    static func results(isolation: isolated (any ModelActor) = #isolation) throws -> [Self] {
        try query().results()
    }

    /// Constructs an empty query over this model type and invokes ``Query/fetchedResults(isolation:)`` on that query.
    static func fetchedResults(
        isolation: isolated (any ModelActor) = #isolation
    ) throws -> FetchResultsCollection<Self>  {
        try query().fetchedResults()
    }

    /// Constructs an empty query over this model type and invokes ``Query/fetchedResults(batchSize:isolation:)`` on that query.
    static func fetchedResults(
        batchSize: Int,
        isolation: isolated (any ModelActor) = #isolation
    ) throws -> FetchResultsCollection<Self> {
        try query().fetchedResults(batchSize: batchSize)
    }

    /// Constructs an empty query over this model type and invokes ``Query/count(isolation:)`` on that query.
    static func count(isolation: isolated (any ModelActor) = #isolation) throws -> Int {
        try query().count()
    }

    /// Constructs an empty query over this model type and invokes ``Query/isEmpty(isolation:)`` on that query.
    static func isEmpty(isolation: isolated (any ModelActor) = #isolation) throws -> Bool {
        try query().isEmpty()
    }

    /// Constructs an empty query over this model type and invokes ``Query/findOrCreate(isolation:body:)`` on that query.
    static func findOrCreate(
        isolation: isolated (any ModelActor) = #isolation,
        body: () -> Self
    ) throws -> Self {
        try query().findOrCreate(body: body)
    }

    /// Constructs an empty query over this model type and invokes ``Query/delete(isolation:)`` on that query.
    /// This is named `deleteAll` rather than `delete` to signify with an empty query this will match all objects.
    static func deleteAll(
        isolation: isolated (any ModelActor) = #isolation
    ) throws {
        try query().delete()
    }
}
