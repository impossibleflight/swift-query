import Foundation
import CoreData
import Dependencies
import SwiftData

/// Fetches and tracks the first result of a query, or the first row of a projection, if any.
///
/// Given a ``Query``, the wrapped value is the first matching model, fetched on the main context
/// and fetched again after every change to the store. Given a ``Projection``, the wrapped value is
/// the first projected row, fetched on a ``QueryActor`` and fetched again whenever the store records
/// a change to the projection's model type or to a type it joins. The row arrives asynchronously,
/// so the wrapped value is `nil` until the first fetch completes.
///
/// ```swift
/// @FetchFirst(Person.include(#Predicate { $0.name == "Jack" }))
/// var jack: Person?
///
/// @FetchFirst(Author.include(#Predicate { $0.name == "Ursula" }).select(AuthorRow.init))
/// var ursula: AuthorRow?
/// ```
@MainActor
@propertyWrapper
public final class FetchFirst<Element> {
    public var wrappedValue: Element? {
        storage.wrappedValue
    }
    private var storage: Storage = .init()
    private var subscription: (Task<Void, Never>)?
    @Dependency(\.modelContainer) private var modelContainer

    /// Tracks the first model matching `query`, fetched on the main context.
    public init(_ query: Query<Element>) where Element: PersistentModel {
        subscribe(query)
    }

    /// Tracks the first row of `projection`, fetched on a ``QueryActor``.
    public init<T>(_ projection: Projection<T, Element>) where Element: Sendable {
        debug { logger.debug("\(Self.self).\(#function)(query: \(String(describing: projection.query))") }
        subscription = observe(projection, in: modelContainer) { projection, actor in
            try projection.first(isolation: actor)
        } update: { [storage] row in
            trace { logger.trace("\(Self.self).first: \(row == nil ? "nil" : "row")") }
            storage.wrappedValue = row
        }
    }

    deinit {
        subscription?.cancel()
    }

    private func subscribe(_ query: Query<Element>) where Element: PersistentModel {
        debug { logger.debug("\(Self.self).\(#function)(query: \(String(describing: query))") }
        subscription = Task { [modelContainer = self.modelContainer] in
            do {
                let initialResult = try query.first(in: modelContainer)
                trace { logger.trace("\(Self.self).first: \(String(describing: initialResult?.persistentModelID))") }
                storage.wrappedValue = initialResult

                let changeNotifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)

                for try await _ in changeNotifications {
                    guard !Task.isCancelled else { break }
                    debug { logger.debug("\(Self.self).NSPersistentStoreRemoteChange")}
                    let result = try query.first(in: modelContainer)
                    trace { logger.trace("\(Self.self).first: \(String(describing: result?.persistentModelID))") }
                    storage.wrappedValue = result
                }
            } catch {
                logger.error("\(error)")
            }
        }
    }

    @Observable
    internal class Storage {
        var wrappedValue: Element?
        init() {}
    }
}
