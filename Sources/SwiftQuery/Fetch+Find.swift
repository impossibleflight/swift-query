import Foundation
import SwiftData

@MainActor
public extension Query {
    /// Returns the object with `id` that matches the query, or `nil` if there is none.
    ///
    /// SwiftData compares an identifier in a predicate by its row number alone, so this fetches
    /// by the identifier and then confirms the result's own identifier is the one asked for. A
    /// record that is gone, or an identifier from another container, gives `nil`, never another
    /// record. See ``PersistentModel/find(_:in:)`` for the static form.
    ///
    /// ```swift
    /// let author = try Author.include(#Predicate { $0.born != nil }).find(id, in: container)
    /// ```
    func find(_ id: ModelID<T>, in container: ModelContainer) throws -> T? {
        try find(id.persistentIdentifier, in: container)
    }

    /// ``find(_:in:)`` for an identifier that arrived untyped. An identifier of another kind of
    /// model gives `nil`.
    func find(_ id: PersistentIdentifier, in container: ModelContainer) throws -> T? {
        try identified(by: id).first(in: container).flatMap { $0.persistentModelID == id ? $0 : nil }
    }
}

public extension Query {
    /// Returns the object with `id` that matches the query from the current model actor's context,
    /// or `nil` if there is none. See ``find(_:in:)`` for the check this makes.
    func find(_ id: ModelID<T>, isolation: isolated (any ModelActor) = #isolation) throws -> T? {
        try find(id.persistentIdentifier, isolation: isolation)
    }

    /// ``find(_:isolation:)`` for an identifier that arrived untyped. An identifier of another
    /// kind of model gives `nil`.
    func find(_ id: PersistentIdentifier, isolation: isolated (any ModelActor) = #isolation) throws -> T? {
        try identified(by: id).first(isolation: isolation).flatMap { $0.persistentModelID == id ? $0 : nil }
    }
}

private extension Query {
    func identified(by id: PersistentIdentifier) -> Query<T> {
        include(#Predicate { $0.persistentModelID == id })
    }
}

@MainActor
public extension PersistentModel {
    /// Returns the object with `id`, or `nil` if there is none. See ``Query/find(_:in:)``.
    ///
    /// ```swift
    /// if let author = try Author.find(row.author, in: container) { ... }
    /// ```
    static func find(_ id: ModelID<Self>, in container: ModelContainer) throws -> Self? {
        try query().find(id, in: container)
    }

    /// ``find(_:in:)`` for an identifier that arrived untyped. See ``Query/find(_:in:)``.
    static func find(_ id: PersistentIdentifier, in container: ModelContainer) throws -> Self? {
        try query().find(id, in: container)
    }
}

public extension PersistentModel {
    /// Returns the object with `id` from the current model actor's context, or `nil` if there is
    /// none. See ``Query/find(_:isolation:)``.
    static func find(_ id: ModelID<Self>, isolation: isolated (any ModelActor) = #isolation) throws -> Self? {
        try query().find(id, isolation: isolation)
    }

    /// ``find(_:isolation:)`` for an identifier that arrived untyped. See ``Query/find(_:isolation:)``.
    static func find(_ id: PersistentIdentifier, isolation: isolated (any ModelActor) = #isolation) throws -> Self? {
        try query().find(id, isolation: isolation)
    }
}
