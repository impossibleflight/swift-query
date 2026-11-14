import Foundation
import SwiftData

public extension Query {
    /// Narrows the query to objects whose relationship at `keyPath` is the model with `id`.
    ///
    /// A predicate comparing an identifier is translated by SwiftData to a row-number match, so
    /// one written by hand against an untyped identifier of the wrong kind matches a stranger. The
    /// typed identifier makes the kind a compile-time fact. See
    /// ``PersistentModel/include(_:is:)`` for the static form.
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
