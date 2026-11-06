import Foundation
import CoreData
import SwiftData

/// Performs a projection on a ``QueryActor`` and performs it again whenever the store records a
/// change to one of the model types the projection reads.
///
/// The first value arrives asynchronously, after the actor has fetched. From then on every
/// `NSPersistentStoreRemoteChange` is answered by reading the persistent history written since
/// the last read; if any transaction touched the projection's root type or a joined type, the
/// projection is performed again and `update` is called on the main actor with the new value.
/// Changes to other types are ignored.
@MainActor
func observe<T, Row, Value: Sendable>(
    _ projection: Projection<T, Row>,
    in container: ModelContainer,
    fetch: @escaping @Sendable (Projection<T, Row>, isolated QueryActor) throws -> Value,
    update: @escaping @MainActor (Value) -> Void
) -> Task<Void, Never> {
    Task {
        let actor = container.createQueryActor()
        let entities = projection.query.entityNames(in: container.schema)
        // Cursor and iterator are both set up before the first fetch, so a change that lands
        // while that fetch is running is neither lost nor read as part of the initial state.
        var cursor = HistoryCursor.since(Date())
        let changes = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange).makeAsyncIterator()
        do {
            update(try await actor.perform { try fetch(projection, $0) })
            while await changes.next() != nil {
                guard !Task.isCancelled else { break }
                let changed: Set<String>
                (changed, cursor) = try await actor.changedEntityNames(after: cursor)
                debug { logger.debug("ProjectionObserver.NSPersistentStoreRemoteChange changed: \(changed) watching: \(entities)") }
                guard !changed.isDisjoint(with: entities) else { continue }
                update(try await actor.perform { try fetch(projection, $0) })
            }
        } catch {
            logger.error("\(error)")
        }
    }
}

/// Where a reader of persistent history is up to: either a point in time, before any transaction
/// has been seen, or the token of the last transaction read.
enum HistoryCursor: Sendable {
    case since(Date)
    case after(DefaultHistoryToken)
}

extension QueryActor {
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
