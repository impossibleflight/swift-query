import Foundation
import SwiftData

/// A query that reads one relationship of its results, ready to be projected into a row type
/// with ``select(_:)``.
///
/// Build one with ``Query/joining(_:)``. Every refinement already applied to the query stays in
/// force, and the joined relationship is prefetched so the related objects arrive with the results
/// rather than as a fault per row.
///
/// ```swift
/// let rows = try Book
///     .include(#Predicate { $0.title != "Anonymous" })
///     .sortBy(\.title)
///     .joining(\.author)
///     .select { book, author in
///         BookWithAuthor(book: BookRow(book), authorName: author?.name)
///     }
///     .results(in: container)
/// ```
///
/// This is not a database join. The related objects are fetched by SwiftData and handed to the
/// `select` closure in memory, so a count over a to-many relationship is computed in memory too.
//
// A single key path has its own type rather than being a one-element ``MultiJoin`` because, as of
// Swift 6.4, optional chaining on a closure parameter typed by a one-element parameter pack does
// not compile (`author?.name` fails, `author.map(\.name)` works). Keeping packs out of the common
// case spares callers that wart.
public struct Join<T: PersistentModel, Related>: Sendable {
    /// The query whose results are projected.
    public var query: Query<T>
    let keyPath: any KeyPath<T, Related> & Sendable

    /// Projects each result and its joined relationship into a value of `Row`.
    ///
    /// The closure receives the model and the relationship's value, typed as it is declared: the
    /// related model, an optional, or an array. It runs inside the context that performs the
    /// fetch; only the rows leave it.
    public func select<Row: Sendable>(
        _ transform: @escaping @Sendable (T, Related) -> Row
    ) -> Projection<T, Row> {
        let keyPath = keyPath
        return Projection(query: query) { model in
            transform(model, model[keyPath: keyPath])
        }
    }
}

/// A query that reads several relationships of its results, ready to be projected into a row type
/// with ``select(_:)``.
///
/// Build one with ``Query/joining(_:)-((repeat_)_)`` by passing more than one key path. It behaves
/// as ``Join`` does, with one `select` argument per key path.
public struct MultiJoin<T: PersistentModel, each Related>: Sendable {
    /// The query whose results are projected.
    public var query: Query<T>
    let keyPaths: (repeat any KeyPath<T, each Related> & Sendable)

    /// Projects each result and its joined relationships into a value of `Row`.
    ///
    /// The closure receives the model followed by one argument per joined key path, in order,
    /// typed as the relationship is declared: the related model, an optional, or an array. It
    /// runs inside the context that performs the fetch; only the rows leave it.
    public func select<Row: Sendable>(
        _ transform: @escaping @Sendable (T, repeat each Related) -> Row
    ) -> Projection<T, Row> {
        let keyPaths = keyPaths
        return Projection(query: query) { model in
            transform(model, repeat model[keyPath: each keyPaths])
        }
    }
}

public extension Query {
    /// Reads a relationship alongside each result, so ``Join/select(_:)`` receives its value.
    ///
    /// The relationship is prefetched.
    func joining<Related>(_ keyPath: any KeyPath<T, Related> & Sendable) -> Join<T, Related> {
        Join(query: prefetchRelationships(keyPath), keyPath: keyPath)
    }

    /// Reads several relationships alongside each result, so ``MultiJoin/select(_:)`` receives
    /// their values in the same order.
    ///
    /// Each relationship is prefetched.
    func joining<each Related>(
        _ keyPaths: repeat any KeyPath<T, each Related> & Sendable
    ) -> MultiJoin<T, repeat each Related> {
        var prefetched: [PartialKeyPath<T> & Sendable] = []
        repeat prefetched.append(each keyPaths)
        return MultiJoin(query: prefetchRelationships(prefetched), keyPaths: (repeat each keyPaths))
    }

    /// Projects each result into a value of `Row`.
    ///
    /// The closure runs inside the context that performs the fetch, so it may read any property
    /// of the model. Only the rows leave the context.
    func select<Row: Sendable>(_ transform: @escaping @Sendable (T) -> Row) -> Projection<T, Row> {
        Projection(query: self, transform: transform)
    }
}

/// A query whose results are mapped into values of `Row` as they are fetched.
///
/// Rows are `Sendable`, so a projection performed inside a model actor can return them across
/// the actor boundary, which a query returning models cannot. The projection itself is `Sendable`
/// too, so it can be built on the main actor and performed on a ``QueryActor``, which is what
/// ``FetchAll`` and ``FetchFirst`` do with one.
public struct Projection<T: PersistentModel, Row: Sendable>: Sendable {
    /// The query whose results are projected.
    public var query: Query<T>
    let transform: @Sendable (T) -> Row
}

@MainActor
public extension Projection {
    /// Fetches the query's results from the container's main context and projects each one.
    func results(in container: ModelContainer) throws -> [Row] {
        try query.results(in: container).map(transform)
    }

    /// Fetches the query's first result from the container's main context and projects it.
    func first(in container: ModelContainer) throws -> Row? {
        try query.first(in: container).map(transform)
    }

    /// Fetches the query's last result from the container's main context and projects it.
    func last(in container: ModelContainer) throws -> Row? {
        try query.last(in: container).map(transform)
    }
}

public extension Projection {
    /// Fetches the query's results from the current model actor's context and projects each one.
    func results(isolation: isolated (any ModelActor) = #isolation) throws -> [Row] {
        try query.results(isolation: isolation).map(transform)
    }

    /// Fetches the query's first result from the current model actor's context and projects it.
    func first(isolation: isolated (any ModelActor) = #isolation) throws -> Row? {
        try query.first(isolation: isolation).map(transform)
    }

    /// Fetches the query's last result from the current model actor's context and projects it.
    func last(isolation: isolated (any ModelActor) = #isolation) throws -> Row? {
        try query.last(isolation: isolation).map(transform)
    }
}
