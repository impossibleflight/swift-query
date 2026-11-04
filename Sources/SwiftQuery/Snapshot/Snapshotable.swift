import SwiftData

/// Generates a value-type `Snapshot` of a model's stored properties, and a `snapshot` property
/// that produces one.
///
/// Apply it beside `@Model`:
///
/// ```swift
/// @Snapshotable
/// @Model final class Person {
///     var name: String
///     var age: Int
///     var friends: [Person]
/// }
/// ```
///
/// This adds a nested `Person.Snapshot`, which is `Identifiable`, `Hashable` and `Sendable`:
///
/// ```swift
/// struct Snapshot: Identifiable, Hashable, Sendable {
///     let persistentModelID: PersistentIdentifier
///     let name: String
///     let age: Int
///     let friends: [PersistentIdentifier]
///     var id: PersistentIdentifier { persistentModelID }
/// }
/// var snapshot: Snapshot { ... }
/// ```
///
/// Every stored property is mirrored through ``Snapshotted``, so related models arrive as
/// identifiers, never as objects, and the snapshot can cross actor boundaries. If the model has
/// a stored `id` property, the snapshot uses it for `Identifiable` instead of the persistent one.
///
/// Properties marked `@Transient`, computed properties and static members are left out. Each
/// stored property needs an explicit type annotation, and each stored type must be
/// ``SnapshotConvertible``. The model itself is made `SnapshotConvertible`, so other snapshots can
/// refer to it by identifier.
@attached(member, names: named(Snapshot), named(snapshot))
@attached(extension, conformances: SnapshotConvertible)
public macro Snapshotable() = #externalMacro(module: "SwiftQueryMacros", type: "SnapshotableMacro")
