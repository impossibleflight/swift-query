import Foundation
import SwiftData

/// A type whose values can be carried out of a model context inside a ``Snapshotable`` snapshot.
///
/// Stored value types are their own snapshot value. A `PersistentModel` is represented by its
/// `PersistentIdentifier`, never by a copy, so a snapshot never holds another model. Optionals and
/// arrays map their contents.
///
/// Conform your own stored value types with an empty extension; any `Hashable & Sendable` type
/// gets the identity mapping for free:
///
/// ```swift
/// enum Mood: String, Codable { case up, down }
/// extension Mood: SnapshotConvertible {}
/// ```
public protocol SnapshotConvertible {
    /// The value a snapshot stores for `Self`.
    associatedtype SnapshotValue: Hashable & Sendable

    /// The value a snapshot stores for this instance.
    var snapshotValue: SnapshotValue { get }
}

/// The type a snapshot stores for a model property declared as `T`.
///
/// ``Snapshotable`` declares every mirrored property with this alias, so a `String` stays a
/// `String`, a related model becomes a `PersistentIdentifier`, and `[Related]` becomes
/// `[PersistentIdentifier]`.
public typealias Snapshotted<T: SnapshotConvertible> = T.SnapshotValue

public extension SnapshotConvertible where Self: Hashable & Sendable, SnapshotValue == Self {
    var snapshotValue: Self { self }
}

public extension SnapshotConvertible where Self: PersistentModel, SnapshotValue == PersistentIdentifier {
    var snapshotValue: PersistentIdentifier { persistentModelID }
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
