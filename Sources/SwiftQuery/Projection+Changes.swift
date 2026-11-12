import Foundation
import CoreData
import SwiftData

public extension Projection {
    /// The projection's rows now, and again after every change to a model type it reads.
    ///
    /// The sequence is performed on the model actor that calls it. Its first element is the rows
    /// as they stand, fetched when iteration begins. From then on every `NSPersistentStoreRemoteChange`
    /// is answered by reading the persistent history written since the last read, and if a
    /// transaction touched the projection's model type or a type it joins, the rows are fetched
    /// again and delivered as the next element. Changes to other types produce nothing. A failed
    /// fetch or history read ends the sequence by throwing, so a caller deciding state on the rows
    /// sees the failure rather than a stale value.
    ///
    /// Every call sets up its own cursor into the history, before its first fetch, so any number of
    /// sequences can be live at once and each one sees every change. Ending the iteration stops the
    /// observation.
    ///
    /// ```swift
    /// @ModelActor
    /// actor Library {
    ///     func watch() async throws {
    ///         for try await rows in Book.sortBy(\.title).select(BookRow.init).changes() {
    ///             // rows is [BookRow]
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ``FetchAll`` and ``FetchFirst`` observe a projection the same way on a ``QueryActor`` of
    /// their own, but log a failure and keep the last value where this sequence throws.
    func changes(isolation: isolated (any ModelActor) = #isolation) -> AsyncThrowingStream<[Row], any Error> {
        changes(isolation: isolation) { projection, actor in
            try projection.results(isolation: actor)
        }
    }
}

extension Projection {
    /// ``changes(isolation:)`` with the fetch left to the caller, so ``FetchFirst`` can fetch one
    /// row where ``FetchAll`` fetches them all.
    func changes<Value: Sendable>(
        isolation: isolated (any ModelActor) = #isolation,
        fetch: @escaping @Sendable (Projection, isolated any ModelActor) throws -> Value
    ) -> AsyncThrowingStream<Value, any Error> {
        let entities = query.entityNames(in: isolation.modelContainer.schema)
        return AsyncThrowingStream { continuation in
            let task = Task {
                // Cursor and iterator are both set up before the first fetch, so a change that
                // lands while that fetch is running is neither lost nor read as part of the
                // initial state.
                var cursor = HistoryCursor.since(Date())
                let notifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange).makeAsyncIterator()
                do {
                    continuation.yield(try fetch(self, isolation))
                    while await notifications.next() != nil {
                        guard !Task.isCancelled else { break }
                        let changed: Set<String>
                        (changed, cursor) = try isolation.changedEntityNames(after: cursor)
                        debug { logger.debug("Projection.changes NSPersistentStoreRemoteChange changed: \(changed) watching: \(entities)") }
                        guard !changed.isDisjoint(with: entities) else { continue }
                        continuation.yield(try fetch(self, isolation))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Where a reader of persistent history is up to: either a point in time, before any transaction
/// has been seen, or the token of the last transaction read.
enum HistoryCursor: Sendable {
    case since(Date)
    case after(DefaultHistoryToken)
}

extension ModelActor {
    /// Reads the persistent history recorded after `cursor` and returns the names of every entity
    /// changed in it, with the cursor to use for the next read.
    func changedEntityNames(after cursor: HistoryCursor) throws -> (Set<String>, HistoryCursor) {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        switch cursor {
        case .since(let date):
            descriptor.predicate = #Predicate { $0.timestamp >= date }
        case .after(let token):
            descriptor.predicate = #Predicate { $0.token > token }
        }
        let transactions = try modelContext.fetchHistory(descriptor)
        var changed: Set<String> = []
        for transaction in transactions {
            for change in transaction.changes {
                changed.insert(change.changedPersistentIdentifier.entityName)
            }
        }
        let next = transactions.last.map { HistoryCursor.after($0.token) } ?? cursor
        return (changed, next)
    }
}

extension Query {
    /// The names of the entities a fetch of this query reads: the model's own entity and the
    /// destination of every prefetched relationship, as `joining` records them.
    func entityNames(in schema: Schema) -> Set<String> {
        let root = Schema.entityName(for: T.self)
        var names: Set<String> = [root]
        guard let entity = schema.entities.first(where: { $0.name == root }) else { return names }
        for keyPath in relationshipKeyPaths {
            let keyPath = keyPath as AnyKeyPath
            for relationship in entity.relationships where relationship.keypath == keyPath {
                names.insert(relationship.destination)
            }
        }
        return names
    }
}
