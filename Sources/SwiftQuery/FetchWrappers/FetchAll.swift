import Foundation
import CoreData
import Dependencies
import SwiftData

/// Fetches and tracks every result of a query, or every row of a projection.
///
/// Given a ``Query``, the wrapped value is the matching models, fetched on the main context and
/// fetched again after every change to the store. Given a ``Projection``, the wrapped value is the
/// projected rows, fetched on a ``QueryActor`` and fetched again whenever the store records a change
/// to the projection's model type or to a type it joins. The rows arrive asynchronously, so the
/// wrapped value is empty until the first fetch completes.
///
/// ```swift
/// @FetchAll(Person.include(#Predicate { $0.age >= 18 }))
/// var adults: [Person]
///
/// @FetchAll(Book.sortBy(\.title).joining(\.author).select { book, author in
///     BookWithAuthor(book: BookRow(book), authorName: author?.name)
/// })
/// var books: [BookWithAuthor]
/// ```
@MainActor
@propertyWrapper
public final class FetchAll<Element>: Observable {
    public var wrappedValue: [Element] {
        storage.wrappedValue
    }
    private var storage: Storage = .init()
    private var subscription: (Task<Void, Never>)?
    @Dependency(\.modelContainer) private var modelContainer

    /// Tracks the models matching `query`, fetched on the main context.
    public init(_ query: Query<Element> = .init()) where Element: PersistentModel {
        subscribe(query)
    }

    /// Tracks the rows of `projection`, fetched on a ``QueryActor``.
    public init<T>(_ projection: Projection<T, Element>) where Element: Sendable {
        debug { logger.debug("\(Self.self).\(#function)(query: \(String(describing: projection.query))") }
        subscription = observe(projection, in: modelContainer) { projection, actor in
            try projection.results(isolation: actor)
        } update: { [storage] rows in
            trace { logger.trace("\(Self.self).results: \(rows.count) rows") }
            storage.wrappedValue = rows
        }
    }

    deinit {
        subscription?.cancel()
    }

    private func subscribe(_ query: Query<Element>) where Element: PersistentModel {
        debug { logger.debug("\(Self.self).\(#function)(query: \(String(describing: query))") }
        subscription = Task { [modelContainer = self.modelContainer] in
            do {
                let initialResult = try query.results(in: modelContainer)
                trace {
                    logger.trace("\(Self.self).results: \(String(describing: initialResult.map { $0.persistentModelID } ))")
                }
                storage.wrappedValue = initialResult

                let changeNotifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)

                for try await _ in changeNotifications {
                    guard !Task.isCancelled else { break }
                    debug { logger.debug("\(Self.self).NSPersistentStoreRemoteChange")}
                    let result = try query.results(in: modelContainer)
                    trace {
                        logger.trace("\(Self.self).results: \(String(describing: result.map { $0.persistentModelID } ))")
                    }
                    storage.wrappedValue = result
                }
            } catch {
                logger.error("\(error)")
            }
        }
    }

    @Observable
    internal class Storage {
        var wrappedValue: [Element] = []
        init() {}
    }
}
