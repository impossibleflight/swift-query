# AGENTS.md

Guidance for coding agents working in this repository. `CLAUDE.md` imports this file.

## What's in this repo

SwiftQuery, a query language for SwiftData published as a Swift package. A `Query<T>` wraps a `FetchDescriptor` and is built by chaining refinements; it is then performed on the main actor or inside any `ModelActor`.

- `Sources/SwiftQuery/` — the library, one file per concern
- `Sources/SwiftQueryMacros/` — the `@Snapshotable` macro, on swift-syntax
- `Tests/SwiftQueryTests/` — Swift Testing suites, one per source file. `Model.swift` holds the `Person` model the query suites share; `SnapshotModels.swift` holds `Author` and `Book`, related models for the snapshot and join suites

Read [README.md](README.md) first for what SwiftQuery is and how it is used, and [CONTRIBUTING.md](CONTRIBUTING.md) before writing or reviewing code: it carries the commands, the style and the testing conventions, and this file does not repeat them.

## Current phase

Released, at 1.2.0, and in use by apps. Semantic versioning: a breaking change to the public API is a major version, new API a minor, a fix a patch. Say which in the PR.

Unreleased on the `snapshotable` branch: `@Snapshotable` value snapshots of models and `joining`/`select` projections into declared row types. Still to design with the lead: observable queries that yield those values rather than models, which needs `Query` to become `Sendable`.

## How SwiftQuery works

**Two API surfaces, one implementation.** Operations exist as instance methods on `Query<T>` and, where they make sense without a query in hand, as static methods on `PersistentModel` (`Person.include(...)`, `Person.results(in:)`). `Person.any` stands in for `first` and `Person.deleteAll` for `delete`; `last` and `reverse` have no static form. The static forms in `PersistentModel+Query.swift` and `PersistentModel+Fetch.swift` only delegate to `Query`; behaviour lives in `Query`. When adding an operation, add the static form too if it has one, and keep the documentation cross-linked.

**Refinements are immutable.** Every refinement returns a new `Query` carrying all five fields: predicate, sort descriptors, range, prefetched relationships and properties to fetch. A refinement that forgets to pass one through silently drops it, and the tests in `QueryTests.swift` are where that shows up.

**Predicates compound with AND.** `include` ANDs the new predicate with any existing one by evaluating both inside a new `#Predicate`. `exclude` is `include` of the negation. There is no OR; build one inside a single `#Predicate` instead.

**`AnySortDescriptor` exists because of a SwiftData bug.** Changing `SortDescriptor.order` after construction has no effect on the fetch (Apple Feedback FB18433460). So a sort is stored as a builder closure plus an order, and the real `SortDescriptor` is rebuilt with that order each time `fetchDescriptor` is read. `reverse()` flips every stored order. Do not replace this with a plain `[SortDescriptor<T>]`.

**Two execution paths.** `Fetch+MainActor.swift` is `@MainActor` and takes `in container:`, fetching on `container.mainContext`. `Fetch+Concurrency.swift` takes `isolation: isolated (any ModelActor) = #isolation`, so the same call compiles inside any model actor and fetches on that actor's context. `QueryActor` is a stock `@ModelActor` whose `perform` runs a closure isolated to it; only `Sendable` values can be returned, which is what keeps models inside their context at compile time.

**Fetch wrappers are main-actor classes driven by notifications.** `FetchFirst`, `FetchAll` and `FetchResults` take their container from the swift-dependencies value `\.modelContainer`, fetch on the main context, store the result in an `@Observable` box, and re-fetch on every `NSPersistentStoreRemoteChange`. The default dependency value is a blank in-memory container and reports an issue, so an app must set `modelContainer` in `prepareDependencies`, and tests use `withDependencies`. Inside an `@Observable` type they need `@ObservationIgnored`, as the README says.

**Snapshots are typed by the type system, not the macro.** `@Snapshotable` mirrors each stored property as `Snapshotted<DeclaredType>`, an alias for `SnapshotConvertible.SnapshotValue`. The macro never decides whether a property is a relationship; the conformances in `SnapshotConvertible.swift` do: a `PersistentModel` becomes its `PersistentIdentifier`, optionals and arrays map their contents, value types map to themselves. A stored type without a conformance is a compile error at the use site. `SnapshotSchemaTests` checks the generated snapshots against the Core Data model SwiftData builds for the same classes.

**Joins are prefetches plus a typed closure.** `joining(\.author)` records the key path, adds it to `relationshipKeyPathsForPrefetching`, and hands the relationship's value to `select` beside the model. The `select` closure runs inside the fetching context, so only the `Sendable` rows leave it. `Join` (one key path) and `MultiJoin` (several, via parameter packs) are separate types because of a compiler bug noted in `Join.swift`.

**Logging is off unless asked for.** `Logging.swift` writes through `OSLog` only when the environment variable `com.impossibleflight.SwiftQuery.debug` or `com.impossibleflight.SwiftQuery.trace` is `true`.

## Documentation

- [README.md](README.md) — what SwiftQuery is, every operation with an example, the concurrency model, the fetch wrappers
- Public symbols carry DocC comments, cross-linked with ``Type/method(param:)``; there is no DocC catalog yet
