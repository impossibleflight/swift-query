import Foundation
import SwiftData
@testable import SwiftQuery
import Testing

/// `Projection.changes(isolation:)`: a throwing sequence of rows, performed on the caller's actor
/// and refreshed when a type the projection reads changes.
@MainActor
struct ProjectionChangesTests {
    struct Row: Hashable, Sendable {
        var title: String
        var authorName: String?
    }

    let container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Author.self, Book.self, Person.self, configurations: config)
    }

    var rows: Projection<Book, Row> {
        Book.sortBy(\.title).joining(\.author).select { book, author in
            Row(title: book.title, authorName: author?.name)
        }
    }

    /// Starts observing `projection` on a fresh actor and returns its iterator once the first
    /// element has been read, so a change made after this returns is seen as a change.
    func observe<T, Row: Sendable>(
        _ projection: Projection<T, Row>
    ) async throws -> (first: [Row], iterator: AsyncThrowingStream<[Row], any Error>.AsyncIterator) {
        let actor = container.createQueryActor()
        var iterator = await projection.changes(isolation: actor).makeAsyncIterator()
        let first = try await next(of: &iterator)
        return (first, iterator)
    }

    /// Reads the next element, failing the test if the sequence has ended. Reading in two steps
    /// keeps the iterator out of the `#require` closure, and `isolation:` keeps it on this actor.
    func next<Row: Sendable>(of iterator: inout AsyncThrowingStream<[Row], any Error>.AsyncIterator) async throws -> [Row] {
        let value = try await iterator.next(isolation: #isolation)
        return try #require(value)
    }

    func insertUrsula(withBooks titles: [String]) throws -> Author {
        let ursula = Author(name: "Ursula")
        try container.mainContext.transaction {
            container.mainContext.insert(ursula)
            for title in titles {
                container.mainContext.insert(Book(title: title, genre: .fiction, author: ursula))
            }
        }
        return ursula
    }

    @Test func changes_beginsWithTheCurrentRows() async throws {
        try insertUrsula(withBooks: ["The Dispossessed"])

        let (first, _) = try await observe(rows)

        #expect(first == [Row(title: "The Dispossessed", authorName: "Ursula")])
    }

    @Test func changes_followsTheModelType() async throws {
        var (first, iterator) = try await observe(rows)
        #expect(first.isEmpty)

        try insertUrsula(withBooks: ["The Dispossessed", "The Lathe of Heaven"])

        let next = try await next(of: &iterator)
        #expect(next == [
            Row(title: "The Dispossessed", authorName: "Ursula"),
            Row(title: "The Lathe of Heaven", authorName: "Ursula")
        ])
        _ = first
    }

    @Test func changes_followsAJoinedType() async throws {
        let ursula = try insertUrsula(withBooks: ["The Dispossessed"])
        var (_, iterator) = try await observe(rows)

        try container.mainContext.transaction {
            ursula.name = "Ursula K. Le Guin"
        }

        let next = try await next(of: &iterator)
        #expect(next.map(\.authorName) == ["Ursula K. Le Guin"])
    }

    @Test func changes_ignoresOtherTypes() async throws {
        var (_, iterator) = try await observe(rows)

        try container.mainContext.transaction {
            container.mainContext.insert(Person(name: "Unrelated", age: 1))
        }
        try insertUrsula(withBooks: ["The Dispossessed"])

        // The unrelated save produced nothing, so the first element after it is the related one.
        let next = try await next(of: &iterator)
        #expect(next.map(\.title) == ["The Dispossessed"])
    }

    @Test func changes_areIndependentPerCall() async throws {
        var (_, books) = try await observe(rows)
        var (_, authors) = try await observe(Author.sortBy(\.name).select(AuthorSelection.init))
        var (_, people) = try await observe(Person.sortBy(\.name).select { $0.name })

        try insertUrsula(withBooks: ["The Dispossessed"])

        let nextBooks = try await next(of: &books)
        let nextAuthors = try await next(of: &authors)
        #expect(nextBooks.map(\.title) == ["The Dispossessed"])
        #expect(nextAuthors.map(\.name) == ["Ursula"])

        // The people sequence saw nothing; a later Person save is the first thing it delivers.
        try container.mainContext.transaction {
            container.mainContext.insert(Person(name: "Octavia", age: 1))
        }
        let nextPeople = try await next(of: &people)
        #expect(nextPeople == ["Octavia"])
    }

    struct Failure: Error {}

    /// A predicate SwiftData cannot translate crashes in CoreData rather than throwing, so the
    /// failure is injected through the fetch the public sequence passes to the observation.
    @Test func changes_endsByThrowingWhenAFetchFails() async throws {
        let actor = container.createQueryActor()
        let rows = rows

        await #expect(throws: Failure.self) {
            for try await _ in await rows.changes(isolation: actor, fetch: { _, _ in throw Failure() }) {}
        }
    }
}
