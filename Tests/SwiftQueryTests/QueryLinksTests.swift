import Foundation
import SwiftData
import SwiftQuery
import Testing

/// Narrowing a query by a typed identifier on a relationship.
@MainActor
struct QueryLinksTests {
    let container: ModelContainer
    let ursula: Author
    let octavia: Author
    let dispossessed: Book
    let kindred: Book

    init() throws {
        container = try ModelContainer(for: Author.self, Book.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        ursula = Author(name: "Ursula")
        octavia = Author(name: "Octavia")
        dispossessed = Book(title: "The Dispossessed", genre: .fiction, author: ursula)
        kindred = Book(title: "Kindred", genre: .fiction, author: octavia)
        for model: any PersistentModel in [ursula, octavia, dispossessed, kindred] {
            container.mainContext.insert(model)
        }
        try container.mainContext.save()
    }

    @Test func include_is_narrowsToTheLinkedModel() throws {
        let books = try Book.include(\.author, is: ursula.modelID).results(in: container)
        #expect(books.map(\.title) == ["The Dispossessed"])
    }

    @Test func include_is_composesWithOtherRefinements() throws {
        let none = try Book.include(#Predicate { $0.title == "Kindred" }).include(\.author, is: ursula.modelID).results(in: container)
        #expect(none.isEmpty)
    }

    @Test func include_is_isEmptyForAnUnlinkedModel() throws {
        let orphan = Book(title: "Anonymous", genre: .fiction)
        container.mainContext.insert(orphan)
        try container.mainContext.save()

        let books = try Book.include(\.author, is: octavia.modelID).results(in: container)
        #expect(books.map(\.title) == ["Kindred"])
    }

    @Test func include_contains_narrowsToTheOwner() throws {
        let authors = try Author.include(\.books, contains: kindred.modelID).results(in: container)
        #expect(authors.map(\.name) == ["Octavia"])
    }
}
