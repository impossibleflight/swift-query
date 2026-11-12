import Foundation
import SwiftData

/// Performs a projection on a ``QueryActor`` of its own and performs it again whenever the store
/// records a change to one of the model types the projection reads, through
/// ``Projection/changes(isolation:)``.
///
/// The first value arrives asynchronously, after the actor has fetched. A failed fetch or history
/// read is logged and ends the observation; the wrapper keeps the last value it was given.
@MainActor
func observe<T, Row, Value: Sendable>(
    _ projection: Projection<T, Row>,
    in container: ModelContainer,
    fetch: @escaping @Sendable (Projection<T, Row>, isolated any ModelActor) throws -> Value,
    update: @escaping @MainActor (Value) -> Void
) -> Task<Void, Never> {
    Task {
        let actor = container.createQueryActor()
        do {
            for try await value in await projection.changes(isolation: actor, fetch: fetch) {
                update(value)
            }
        } catch {
            logger.error("\(error)")
        }
    }
}
