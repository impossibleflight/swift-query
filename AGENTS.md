# AGENTS.md

Guidance for coding agents working in this repository. `CLAUDE.md` imports this file.

## What's in this repo

SwiftQuery, a query language for SwiftData published as a Swift package. A `Query<T>` wraps a `FetchDescriptor` and is built by chaining refinements; it is then performed on the main actor or inside any `ModelActor`.

- `Sources/SwiftQuery/` — the library, one file per concern
- `Sources/SwiftQueryMacros/` — the `@Selection` macro, on swift-syntax; `StoredProperties.swift` reads a declaration's stored properties for it
- `Tests/SwiftQueryTests/` — Swift Testing suites, one per source file. `Model.swift` holds the `Person` model the query suites share; `SnapshotModels.swift` holds `Author`, `Book` and `Publisher`, related models for the row and join suites; `SelectionModels.swift` holds rows declared with `@Selection`, and the `Session`/`Visit` inheritance pair, which needs macOS 26

Read [README.md](README.md) first for what SwiftQuery is and how it is used, and [CONTRIBUTING.md](CONTRIBUTING.md) before writing or reviewing code: it carries the commands, the style and the testing conventions, and this file does not repeat them.

## Current phase

Released, at 1.2.0, and in use by apps. Semantic versioning: a breaking change to the public API is a major version, new API a minor, a fix a patch. Say which in the PR.

Unreleased on the `snapshotable` branch, which consumers may track until it is tagged as 1.3.0: `@Selection` rows declared by the consumer and filled from a model, `joining`/`select` projections into those rows, `FetchAll`/`FetchFirst` over a projection, `Projection.changes(isolation:)` as a throwing async sequence of rows on the caller's model actor, and `Query` made `Sendable`. The branch is append-only while it is tracked: no rebasing or force-pushing.

## How SwiftQuery works

**Two API surfaces, one implementation.** Operations exist as instance methods on `Query<T>` and, where they make sense without a query in hand, as static methods on `PersistentModel` (`Person.include(...)`, `Person.results(in:)`). `Person.any` stands in for `first` and `Person.deleteAll` for `delete`; `last` and `reverse` have no static form. The static forms in `PersistentModel+Query.swift` and `PersistentModel+Fetch.swift` only delegate to `Query`; behaviour lives in `Query`. When adding an operation, add the static form too if it has one, and keep the documentation cross-linked.

**Refinements are immutable.** Every refinement returns a new `Query` carrying all five fields: predicate, sort descriptors, range, prefetched relationships and properties to fetch. A refinement that forgets to pass one through silently drops it, and the tests in `QueryTests.swift` are where that shows up.

**Predicates compound with AND.** `include` ANDs the new predicate with any existing one by evaluating both inside a new `#Predicate`. `exclude` is `include` of the negation. There is no OR; build one inside a single `#Predicate` instead.

**`AnySortDescriptor` exists because of a SwiftData bug.** Changing `SortDescriptor.order` after construction has no effect on the fetch (Apple Feedback FB18433460). So a sort is stored as a builder closure plus an order, and the real `SortDescriptor` is rebuilt with that order each time `fetchDescriptor` is read. `reverse()` flips every stored order. Do not replace this with a plain `[SortDescriptor<T>]`.

**Two execution paths.** `Fetch+MainActor.swift` is `@MainActor` and takes `in container:`, fetching on `container.mainContext`. `Fetch+Concurrency.swift` takes `isolation: isolated (any ModelActor) = #isolation`, so the same call compiles inside any model actor and fetches on that actor's context. `QueryActor` is a stock `@ModelActor` whose `perform` runs a closure isolated to it; only `Sendable` values can be returned, which is what keeps models inside their context at compile time.

**Fetch wrappers are main-actor classes driven by notifications.** `FetchFirst`, `FetchAll` and `FetchResults` take their container from the swift-dependencies value `\.modelContainer`, fetch on the main context, store the result in an `@Observable` box, and re-fetch on every `NSPersistentStoreRemoteChange`. The default dependency value is a blank in-memory container and reports an issue, so an app must set `modelContainer` in `prepareDependencies`, and tests use `withDependencies`. Inside an `@Observable` type they need `@ObservationIgnored`, as the README says.

**Projections are observed by entity, on whichever model actor asks.** `Projection.changes(isolation:)` in `Projection+Changes.swift` is the one observation mechanism: an `AsyncThrowingStream` performed on the calling actor. It creates its history cursor and its `NSPersistentStoreRemoteChange` iterator before the first fetch so nothing lands in the gap, yields the rows, and on each notification reads the persistent history since the cursor (`fetchHistory`, a timestamp for the first read and the last token after that) and fetches again only if a transaction touched one of the entities the query reads: its own, plus the destination of each prefetched relationship, resolved through `Schema.Relationship.keypath`. A failed fetch or history read finishes the stream by throwing. Every call has its own cursor and iterator, so sequences are independent. `HistoryDescriptor.sortBy` needs macOS 26, which is why the first read is by timestamp rather than the newest token. `FetchAll` and `FetchFirst` given a `Projection` go through `observe` in `ProjectionObserver.swift`, which iterates that sequence on a `QueryActor` of its own, publishes each value on the main actor, and logs an error instead of throwing; an internal overload takes the fetch as a closure so `FetchFirst` fetches one row. This is why `Query`, `AnySortDescriptor`, `Join` and `Projection` are `Sendable`: a projection built on the main actor is handed to the actor.

**Rows are typed by the type system, not the macro.** `@Selection` sits on the row, not the model. It reads the stored properties of the struct it is attached to and writes `self.name = model.name.snapshotValue` for each one without an initial value; the compiler resolves the model's property, wherever the class hierarchy declares it, and `SnapshotConvertible.swift` maps it: value types map to themselves through the protocol, optionals and arrays map their contents, and models map to their `PersistentIdentifier` through extensions on `PersistentModel`, since a protocol cannot adopt another. A stored type without a mapping, or a name the model lacks, is a compile error at the row. The generated initializer is internal unless `initializer:` raises it, because a public initializer cannot name an internal model.

**Why the macro is not on the model.** An earlier `@Snapshotable` generated a mirror struct from the model's declaration. A macro sees only the declaration it is attached to and its own arguments, never a superclass or what a type name resolves to, so it could not include inherited properties and could not make a snapshot more visible than its model. Putting the macro on the row hands both to the compiler. A frozen-copy design, a detached model on a custom `BackingData`, was also spiked and stopped: it needs reflection for attribute key paths, borrowed metadata, and traps under model inheritance, whose generated initializer casts the backing data to SwiftData's own type. Do not revisit either without new SwiftData API.

**Joins are prefetches plus a typed closure.** `joining(\.author)` records the key path, adds it to `relationshipKeyPathsForPrefetching`, and hands the relationship's value to `select` beside the model. The `select` closure runs inside the fetching context, so only the `Sendable` rows leave it. `Join` (one key path) and `MultiJoin` (several, via parameter packs) are separate types because of a compiler bug noted in `Join.swift`.

**Logging is off unless asked for.** `Logging.swift` writes through `OSLog` only when the environment variable `com.impossibleflight.SwiftQuery.debug` or `com.impossibleflight.SwiftQuery.trace` is `true`.

## Documentation

- [README.md](README.md) — what SwiftQuery is, every operation with an example, the concurrency model, the fetch wrappers
- Public symbols carry DocC comments, cross-linked with ``Type/method(param:)``; there is no DocC catalog yet
