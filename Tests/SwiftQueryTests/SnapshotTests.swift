import Foundation
import SwiftData
import SwiftQuery
import Testing

@MainActor
struct SnapshotTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(
            for: Author.self, Book.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    @Test func mirrorsStoredProperties() throws {
        let born = Date(timeIntervalSince1970: 0)
        let author = Author(name: "Ursula", born: born)
        context.insert(author)
        try context.save()

        let snapshot = author.snapshot
        #expect(snapshot.name == "Ursula")
        #expect(snapshot.born == born)
        #expect(snapshot.persistentModelID == author.persistentModelID)
    }

    @Test func relationshipsBecomeIdentifiers() throws {
        let author = Author(name: "Ursula")
        let book = Book(title: "Earthsea", genre: .fiction, tags: ["wizards"], author: author)
        context.insert(author)
        context.insert(book)
        try context.save()

        let authorSnapshot = author.snapshot
        #expect(authorSnapshot.books == [book.persistentModelID])

        let bookSnapshot = book.snapshot
        #expect(bookSnapshot.author == author.persistentModelID)
        #expect(bookSnapshot.genre == .fiction)
        #expect(bookSnapshot.tags == ["wizards"])
    }

    @Test func optionalRelationshipCanBeNil() throws {
        let book = Book(title: "Orphan", genre: .history)
        context.insert(book)
        try context.save()

        #expect(book.snapshot.author == nil)
    }

    @Test func identifiableUsesPersistentIDWithoutStoredID() throws {
        let author = Author(name: "Ursula")
        context.insert(author)
        try context.save()

        let id: PersistentIdentifier = author.snapshot.id
        #expect(id == author.persistentModelID)
    }

    @Test func identifiableUsesStoredID() throws {
        let uuid = UUID()
        let book = Book(id: uuid, title: "Earthsea", genre: .fiction)
        context.insert(book)
        try context.save()

        let id: UUID = book.snapshot.id
        #expect(id == uuid)
    }

    @Test func snapshotsAreEqualWhenValuesAre() throws {
        let author = Author(name: "Ursula")
        context.insert(author)
        try context.save()

        let before = author.snapshot
        #expect(before == author.snapshot)

        author.name = "Ursula K."
        #expect(before != author.snapshot)
        #expect(before.hashValue != author.snapshot.hashValue)
    }

    @Test func snapshotsCrossActors() async throws {
        let author = Author(name: "Ursula")
        context.insert(author)
        try context.save()

        let snapshot = try await container.createQueryActor().perform { _ in
            try Author.include(#Predicate { $0.name == "Ursula" }).first()?.snapshot
        }
        let found = try #require(snapshot)
        #expect(found.name == "Ursula")
        #expect(found.persistentModelID == author.persistentModelID)
    }
}
