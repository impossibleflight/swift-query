import Foundation
import SwiftData

// Getting from a row back to models: fetching a model by its typed identifier, and narrowing a
// query by a related model's typed identifier, as a row's links hold them.

public extension Query {
    /// ``find(_:in:)-(PersistentIdentifier,_)`` for a typed identifier, such as a row's link.
    ///
    /// ```swift
    /// let author = try Author.include(#Predicate { $0.born != nil }).find(row.author, in: container)
    /// ```
    @MainActor
    func find(_ id: ModelID<T>, in container: ModelContainer) throws -> T? {
        try find(id.persistentIdentifier, in: container)
    }

    /// ``find(_:isolation:)-(PersistentIdentifier,_)`` for a typed identifier, such as a row's link.
    func find(_ id: ModelID<T>, isolation: isolated (any ModelActor) = #isolation) throws -> T? {
        try find(id.persistentIdentifier, isolation: isolation)
    }
}

public extension PersistentModel {
    /// Constructs an empty query over this model type and invokes ``Query/find(_:in:)-(ModelID<T>,_)`` on that query.
    ///
    /// ```swift
    /// if let author = try Author.find(row.author, in: container) { ... }
    /// ```
    @MainActor
    static func find(_ id: ModelID<Self>, in container: ModelContainer) throws -> Self? {
        try query().find(id, in: container)
    }

    /// Constructs an empty query over this model type and invokes ``Query/find(_:isolation:)-(ModelID<T>,_)`` on that query.
    static func find(_ id: ModelID<Self>, isolation: isolated (any ModelActor) = #isolation) throws -> Self? {
        try query().find(id, isolation: isolation)
    }
}

public extension Query {
    /// Narrows the query to objects whose relationship at `keyPath` is the model with `id`.
    ///
    /// SwiftData compares an identifier in a predicate by its row number alone, so a predicate
    /// written by hand against an untyped identifier of the wrong kind matches a stranger, and
    /// nothing can check it afterwards, because the related model is never fetched. The typed
    /// identifier makes the kind a compile-time fact. See ``PersistentModel/include(_:is:)`` for
    /// the static form.
    ///
    /// ```swift
    /// let books = try Book.include(\.author, is: authorID).results(in: container)
    /// ```
    func include<Related: PersistentModel>(
        _ keyPath: any KeyPath<T, Related?> & Sendable,
        is id: ModelID<Related>
    ) -> Self {
        let identifier = id.persistentIdentifier
        return include(Predicate<T> { object in
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_flatMap(
                    PredicateExpressions.build_KeyPath(root: object, keyPath: keyPath)
                ) { related in
                    PredicateExpressions.build_KeyPath(root: related, keyPath: \.persistentModelID)
                },
                rhs: PredicateExpressions.build_Arg(Optional(identifier))
            )
        })
    }

    /// Narrows the query to objects whose relationship at `keyPath` is the model with `id`.
    /// See ``include(_:is:)``.
    func include<Related: PersistentModel>(
        _ keyPath: any KeyPath<T, Related> & Sendable,
        is id: ModelID<Related>
    ) -> Self {
        let identifier = id.persistentIdentifier
        return include(Predicate<T> { object in
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_KeyPath(root: object, keyPath: keyPath),
                    keyPath: \.persistentModelID
                ),
                rhs: PredicateExpressions.build_Arg(identifier)
            )
        })
    }

    /// Narrows the query to objects whose to-many relationship at `keyPath` contains the model
    /// with `id`. See ``include(_:is:)``.
    func include<Related: PersistentModel>(
        _ keyPath: any KeyPath<T, [Related]> & Sendable,
        contains id: ModelID<Related>
    ) -> Self {
        let identifier = id.persistentIdentifier
        return include(Predicate<T> { object in
            PredicateExpressions.build_contains(
                PredicateExpressions.build_KeyPath(root: object, keyPath: keyPath)
            ) { related in
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_KeyPath(root: related, keyPath: \.persistentModelID),
                    rhs: PredicateExpressions.build_Arg(identifier)
                )
            }
        })
    }
}

public extension PersistentModel {
    /// Constructs an empty query over this model type and invokes ``Query/include(_:is:)`` on that query.
    static func include<Related: PersistentModel>(
        _ keyPath: any KeyPath<Self, Related?> & Sendable,
        is id: ModelID<Related>
    ) -> Query<Self> {
        query().include(keyPath, is: id)
    }

    /// Constructs an empty query over this model type and invokes ``Query/include(_:is:)`` on that query.
    static func include<Related: PersistentModel>(
        _ keyPath: any KeyPath<Self, Related> & Sendable,
        is id: ModelID<Related>
    ) -> Query<Self> {
        query().include(keyPath, is: id)
    }

    /// Constructs an empty query over this model type and invokes ``Query/include(_:contains:)`` on that query.
    static func include<Related: PersistentModel>(
        _ keyPath: any KeyPath<Self, [Related]> & Sendable,
        contains id: ModelID<Related>
    ) -> Query<Self> {
        query().include(keyPath, contains: id)
    }
}
