import Foundation
import SwiftData
import SwiftQuery
import Testing

struct BookRow: Hashable, Sendable {
    let title: String
    let authorName: String?
}

struct AuthorRow: Hashable, Sendable {
    let name: String
    let titles: [String]
    let bookCount: Int
}

@MainActor
struct JoinTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Author.self, Book.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let ursula = Author(name: "Ursula")
        let octavia = Author(name: "Octavia")
        context.insert(ursula)
        context.insert(octavia)
        context.insert(Book(title: "Earthsea", genre: .fiction, tags: ["wizards"], author: ursula))
        context.insert(Book(title: "Dispossessed", genre: .fiction, tags: ["anarchists"], author: ursula))
        context.insert(Book(title: "Kindred", genre: .fiction, author: octavia))
        context.insert(Book(title: "Anonymous", genre: .history))
        try context.save()
    }

    @Test func select_projectsEachResult() throws {
        let titles = try Book.sortBy(\.title).select(\.title).results(in: container)
        #expect(titles == ["Anonymous", "Dispossessed", "Earthsea", "Kindred"])
    }

    @Test func select_snapshots() throws {
        let snapshots = try Author.sortBy(\.name).select(\.snapshot).results(in: container)
        #expect(snapshots.map(\.name) == ["Octavia", "Ursula"])
        #expect(snapshots.allSatisfy { !$0.books.isEmpty })
    }

    @Test func joining_toOneOptional() throws {
        let rows = try Book
            .sortBy(\.title)
            .joining(\.author)
            .select { book, author in BookRow(title: book.title, authorName: author?.name) }
            .results(in: container)

        #expect(rows == [
            BookRow(title: "Anonymous", authorName: nil),
            BookRow(title: "Dispossessed", authorName: "Ursula"),
            BookRow(title: "Earthsea", authorName: "Ursula"),
            BookRow(title: "Kindred", authorName: "Octavia"),
        ])
    }

    @Test func joining_toMany() throws {
        let rows = try Author
            .sortBy(\.name)
            .joining(\.books)
            .select { author, books in
                AuthorRow(name: author.name, titles: books.map(\.title).sorted(), bookCount: books.count)
            }
            .results(in: container)

        #expect(rows == [
            AuthorRow(name: "Octavia", titles: ["Kindred"], bookCount: 1),
            AuthorRow(name: "Ursula", titles: ["Dispossessed", "Earthsea"], bookCount: 2),
        ])
    }

    @Test func joining_several() throws {
        let rows = try Book
            .include(#Predicate { $0.title == "Earthsea" })
            .joining(\.author, \.tags)
            .select { book, author, tags in "\(book.title) by \(author?.name ?? "?") about \(tags.joined())" }
            .results(in: container)

        #expect(rows == ["Earthsea by Ursula about wizards"])
    }

    @Test func joining_keepsRefinementsAndPrefetches() throws {
        let join = Book
            .include(#Predicate { $0.title != "Anonymous" })
            .sortBy(\.title)
            .joining(\.author)

        #expect(join.query.predicate != nil)
        #expect(join.query.sortBy.count == 1)
        #expect(join.query.relationshipKeyPaths.count == 1)
        #expect(join.query.relationshipKeyPaths.first == \Book.author)
        #expect(String(describing: type(of: join)) == "Join<Book, Optional<Author>>")
        #expect(String(describing: type(of: Author.joining(\.books))) == "Join<Author, Array<Book>>")
        #expect(String(describing: type(of: Book.joining(\.author, \.tags))) == "MultiJoin<Book, Pack{Optional<Author>, Array<String>}>")
    }

    @Test func first_last() throws {
        let projection = Book.sortBy(\.title).select(\.title)
        #expect(try projection.first(in: container) == "Anonymous")
        #expect(try projection.last(in: container) == "Kindred")
    }

    @Test func rowsCrossActors() async throws {
        let rows = try await container.createQueryActor().perform { _ in
            try Author
                .sortBy(\.name)
                .joining(\.books)
                .select { author, books in
                    AuthorRow(name: author.name, titles: books.map(\.title).sorted(), bookCount: books.count)
                }
                .results()
        }
        #expect(rows.map(\.name) == ["Octavia", "Ursula"])
        #expect(rows.map(\.bookCount) == [1, 2])
    }
}
