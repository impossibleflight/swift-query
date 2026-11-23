import Dependencies
import Foundation
import SwiftData
import SwiftQuery
import Synchronization
import Testing

/// `FetchAll` and `FetchFirst` over a `Projection`: rows fetched on a query actor and refreshed
/// when a type the projection reads changes.
@MainActor
struct FetchProjectionTests {
    struct Row: Hashable, Sendable {
        var title: String
        var authorName: String?
    }

    /// Counts how many times a projection has run.
    final class Counter: Sendable {
        private let count = Mutex(0)
        func increment() { count.withLock { $0 += 1 } }
        var value: Int { count.withLock { $0 } }
    }

    let container: ModelContainer
    let fetches = Counter()

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Author.self, Book.self, Person.self, configurations: config)
    }

    /// Books joined to their author, counting how many times the projection runs.
    var rows: Projection<Book, Row> {
        let fetches = fetches
        return Book.sortBy(\.title).joining(\.author).select { book, author in
            fetches.increment()
            return Row(title: book.title, authorName: author?.name)
        }
    }

    func settle() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    @Test func fetchAll_reflectsChangesToTheModelType() async throws {
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            @FetchAll(rows) var books: [Row]
            try await settle()
            #expect(books.isEmpty)

            let ursula = Author(name: "Ursula")
            try container.mainContext.transaction {
                container.mainContext.insert(ursula)
                container.mainContext.insert(Book(title: "The Dispossessed", genre: .fiction, author: ursula))
                container.mainContext.insert(Book(title: "The Lathe of Heaven", genre: .fiction, author: ursula))
            }
            try await settle()

            #expect(books == [
                Row(title: "The Dispossessed", authorName: "Ursula"),
                Row(title: "The Lathe of Heaven", authorName: "Ursula")
            ])
        }
    }

    @Test func fetchAll_reflectsChangesToAJoinedType() async throws {
        let ursula = Author(name: "Ursula")
        try container.mainContext.transaction {
            container.mainContext.insert(ursula)
            container.mainContext.insert(Book(title: "The Dispossessed", genre: .fiction, author: ursula))
        }

        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            @FetchAll(rows) var books: [Row]
            try await settle()
            #expect(books.map(\.authorName) == ["Ursula"])

            try container.mainContext.transaction {
                ursula.name = "Ursula K. Le Guin"
            }
            try await settle()

            #expect(books.map(\.authorName) == ["Ursula K. Le Guin"])
        }
    }

    @Test func fetchAll_ignoresChangesToOtherTypes() async throws {
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            @FetchAll(rows) var books: [Row]
            try await settle()
            let fetchesBefore = fetches.value

            try container.mainContext.transaction {
                container.mainContext.insert(Person(name: "Unrelated", age: 1))
            }
            try await settle()

            #expect(fetches.value == fetchesBefore)
            _ = books
        }
    }

    @Test func fetchFirst_reflectsChanges() async throws {
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            @FetchFirst(Author.sortBy(\.name).select(AuthorSelection.init)) var first: AuthorSelection?
            try await settle()
            #expect(first == nil)

            try container.mainContext.transaction {
                container.mainContext.insert(Author(name: "Ursula"))
                container.mainContext.insert(Author(name: "Octavia"))
            }
            try await settle()

            #expect(first?.name == "Octavia")
        }
    }
}
