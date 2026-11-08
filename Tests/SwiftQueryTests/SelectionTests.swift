import Foundation
import SwiftData
import SwiftQuery
import Testing

@MainActor
struct SelectionTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(
            for: Author.self, Book.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    @Test func fillsValuesAndIdentifiersFromTheModel() throws {
        let born = Date(timeIntervalSince1970: 0)
        let author = Author(name: "Ursula", born: born)
        let book = Book(title: "Earthsea", genre: .fiction, author: author)
        context.insert(author)
        context.insert(book)
        try context.save()

        let row = AuthorSelection(author)
        #expect(row.name == "Ursula")
        #expect(row.born == born)
        #expect(row.books == [book.persistentModelID])
        #expect(row.id == author.persistentModelID)

        let bookRow = BookSelection(book)
        #expect(bookRow.id == book.id)
        #expect(bookRow.genre == .fiction)
        #expect(bookRow.author == author.persistentModelID)
        #expect(bookRow.isRead == false)
    }

    @Test func buildsFromAnUnsavedModel() {
        let row = AuthorSelection(Author(name: "Draft"))
        #expect(row.name == "Draft")
        #expect(row.books.isEmpty)
    }

    @Test func projectsAQuery() throws {
        context.insert(Author(name: "Octavia"))
        context.insert(Author(name: "Ursula"))
        try context.save()

        let rows = try Author.sortBy(\.name).select(AuthorSelection.init).results(in: container)
        #expect(rows.map(\.name) == ["Octavia", "Ursula"])
    }

    @Test func projectsOnAQueryActor() async throws {
        context.insert(Author(name: "Octavia"))
        try context.save()

        let actor = container.createQueryActor()
        let rows: [AuthorSelection] = try await actor.perform { try Author.select(AuthorSelection.init).results(isolation: $0) }
        #expect(rows.map(\.name) == ["Octavia"])
    }

    @available(macOS 26, iOS 26, watchOS 26, *)
    @Test func selectsInheritedProperties() throws {
        let container = try ModelContainer(
            for: Session.self, Visit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let started = Date(timeIntervalSince1970: 1_000)
        let visit = Visit(startedAt: started, mood: 3)
        container.mainContext.insert(visit)
        try container.mainContext.save()

        let row = VisitSelection(visit)
        #expect(row.startedAt == started)
        #expect(row.endedAt == nil)
        #expect(row.mood == 3)

        let rows = try Visit.select(VisitSelection.init).results(in: container)
        #expect(rows == [row])
    }
}
