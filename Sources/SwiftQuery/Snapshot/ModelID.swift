import Foundation
import SwiftData

/// The identifier of one model, typed by the model it names.
///
/// A `PersistentIdentifier` carries no type, and SwiftData compares one in a predicate by its row
/// number alone, so a `Book`'s identifier handed to a query over `Author` matches whichever author
/// sits in that row. A `ModelID<Author>` cannot be a book's: the compiler refuses it. Rows declared
/// with ``Selection(of:initializer:)`` hold their own identifier and their links as typed
/// identifiers, and ``PersistentModel/find(_:in:)`` fetches one model by its typed identifier.
///
/// ```swift
/// let id: ModelID<Author> = author.modelID
/// let found = try Author.find(id, in: container)   // Author?
/// ```
public struct ModelID<Model: PersistentModel>: Hashable, Sendable {
    /// The untyped identifier this names, for APIs that take one.
    public let persistentIdentifier: PersistentIdentifier

    /// The identifier of `model`.
    public init(_ model: Model) {
        persistentIdentifier = model.persistentModelID
    }

    /// Types an identifier that arrived untyped, or `nil` if it names another kind of model.
    ///
    /// The check is on the identifier's entity name, so it cannot tell a gone record from a live
    /// one; ``PersistentModel/find(_:in:)`` can.
    public init?(_ persistentIdentifier: PersistentIdentifier) {
        guard persistentIdentifier.entityName == Schema.entityName(for: Model.self) else { return nil }
        self.persistentIdentifier = persistentIdentifier
    }
}

extension ModelID: Codable {
    /// Decodes the identifier and refuses one that names another kind of model, as
    /// ``init(_:)-(PersistentIdentifier)`` does, so decoding is not a way around the type.
    public init(from decoder: any Decoder) throws {
        let identifier = try PersistentIdentifier(from: decoder)
        guard let typed = ModelID(identifier) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "\(identifier.entityName) is not a \(Schema.entityName(for: Model.self))"
            ))
        }
        self = typed
    }

    public func encode(to encoder: any Encoder) throws {
        try persistentIdentifier.encode(to: encoder)
    }
}

extension ModelID: CustomStringConvertible {
    public var description: String { "ModelID<\(Model.self)>(\(persistentIdentifier))" }
}

extension ModelID: SnapshotConvertible {}

public extension PersistentModel {
    /// This model's identifier, typed.
    var modelID: ModelID<Self> { .init(self) }
}
