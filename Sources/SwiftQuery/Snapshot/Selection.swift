import SwiftData

/// The visibility of the initializer ``Selection(of:initializer:)`` generates.
public enum SelectionInitializer {
    /// Visible inside the module that declares the row, which is where the models usually are.
    case `internal`
    /// Visible across the package.
    case package
    /// Visible everywhere; the model must be public too.
    case `public`
}

/// Generates an initializer that fills a row struct from a model, property by property, and
/// makes the row `Identifiable`, `Hashable` and `Sendable`.
///
/// Declare the value a screen wants and name the model it is read from:
///
/// ```swift
/// @Selection(of: Book.self)
/// struct BookRow {
///     let id: ModelID<Book>
///     let title: String
///     let author: ModelID<Author>?
/// }
/// ```
///
/// This adds `init(_ model: Book)`, which assigns `model.title.snapshotValue` to `title` and so on
/// for every stored property without an initial value. ``SnapshotConvertible`` does the mapping:
/// a value type arrives as itself and a related model as its ``ModelID``, so a row can leave the
/// context and cross actors. A property whose type does not match is a compile error at
/// the row, and so is a name the model does not have.
///
/// Properties are matched by name, wherever the model declares them, so a row of a subclass can
/// select properties inherited from its parents. A property with an initial value belongs to the
/// row alone and is left out of the initializer.
///
/// A stored `id` declared as `ModelID<Book>` is the model's typed identifier, filled from
/// `model.modelID`, since the model's own `id` is untyped; any other stored `id` is matched by
/// name like the rest. A row with a stored `persistentModelID` and no `id` is `Identifiable` by
/// the untyped identifier. With neither, the row is only `Hashable` and `Sendable`.
///
/// The initializer is internal unless `initializer:` says otherwise, so a public row can be
/// declared for an internal model and built where the model is visible. Pass `.public` when the
/// model is public and other modules compose queries with the row:
///
/// ```swift
/// Book.sortBy(\.title).select(BookRow.init)
/// ```
@attached(member, names: named(init), named(id))
@attached(extension, conformances: Identifiable, Hashable, Sendable)
public macro Selection<Model: PersistentModel>(
    of model: Model.Type,
    initializer: SelectionInitializer = .internal
) = #externalMacro(module: "SwiftQueryMacros", type: "SelectionMacro")
