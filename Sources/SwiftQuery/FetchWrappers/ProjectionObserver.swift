import Foundation
import SwiftData

/// The wrappers' form of ``Projection/changes(isolation:)``: on a ``QueryActor`` of their own, with
/// values published on the main actor, and a failure logged rather than thrown so the wrapped value
/// stays at the last good one.
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
