import Foundation
import SwiftData

/// A type whose values can be carried out of a model context inside a row.
///
/// Stored value types are their own snapshot value, and optionals and arrays map their contents. A
/// `PersistentModel` is represented by its `PersistentIdentifier`, never by a copy, so a row never
/// holds a model; that mapping is an extension on `PersistentModel` rather than a conformance. ``Selection(of:initializer:)`` assigns every property of a row through
/// ``snapshotValue``, which is what makes a mismatched type a compile error at the row.
///
/// Conform your own stored value types with an empty extension; any `Hashable & Sendable` type
/// gets the identity mapping for free:
///
/// ```swift
/// enum Mood: String, Codable { case up, down }
/// extension Mood: SnapshotConvertible {}
/// ```
public protocol SnapshotConvertible {
    /// The value a row stores for `Self`.
    associatedtype SnapshotValue: Hashable & Sendable

    /// The value a row stores for this instance.
    var snapshotValue: SnapshotValue { get }
}

public extension SnapshotConvertible where Self: Hashable & Sendable, SnapshotValue == Self {
    var snapshotValue: Self { self }
}

// Models are not SnapshotConvertible, since a protocol cannot adopt another, but every model and
// every optional or array of one has a snapshotValue of its own, so a row's generated initializer
// reads a relationship the same way it reads a value.
public extension PersistentModel {
    /// The value a row stores for a related model: its identifier, never the model.
    var snapshotValue: PersistentIdentifier { persistentModelID }
}

public extension Optional where Wrapped: PersistentModel {
    /// The value a row stores for an optional related model.
    var snapshotValue: PersistentIdentifier? { self?.persistentModelID }
}

public extension Array where Element: PersistentModel {
    /// The value a row stores for a to-many relationship.
    var snapshotValue: [PersistentIdentifier] { map(\.persistentModelID) }
}

extension Optional: SnapshotConvertible where Wrapped: SnapshotConvertible {
    public var snapshotValue: Wrapped.SnapshotValue? { self?.snapshotValue }
}

extension Array: SnapshotConvertible where Element: SnapshotConvertible {
    public var snapshotValue: [Element.SnapshotValue] { map(\.snapshotValue) }
}

extension String: SnapshotConvertible {}
extension Bool: SnapshotConvertible {}
extension Int: SnapshotConvertible {}
extension Int8: SnapshotConvertible {}
extension Int16: SnapshotConvertible {}
extension Int32: SnapshotConvertible {}
extension Int64: SnapshotConvertible {}
extension UInt: SnapshotConvertible {}
extension UInt8: SnapshotConvertible {}
extension UInt16: SnapshotConvertible {}
extension UInt32: SnapshotConvertible {}
extension UInt64: SnapshotConvertible {}
extension Float: SnapshotConvertible {}
extension Double: SnapshotConvertible {}
extension Decimal: SnapshotConvertible {}
extension Date: SnapshotConvertible {}
extension Data: SnapshotConvertible {}
extension UUID: SnapshotConvertible {}
extension URL: SnapshotConvertible {}
extension PersistentIdentifier: SnapshotConvertible {}
