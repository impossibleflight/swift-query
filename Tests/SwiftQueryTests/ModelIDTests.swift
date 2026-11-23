import Foundation
import SwiftData
import SwiftQuery
import Testing

/// `ModelID`: a typed identifier, and the checks `find` makes that a predicate on an identifier
/// does not, since SwiftData compares one by row number alone.
@MainActor
struct ModelIDTests {
    let container: ModelContainer
    let author: Author
    let book: Book

    init() throws {
        container = try ModelContainer(for: Author.self, Book.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        author = Author(name: "Ursula")
        book = Book(title: "The Dispossessed", genre: .fiction, author: author)
        container.mainContext.insert(author)
        container.mainContext.insert(book)
        try container.mainContext.save()
    }

    @Test func typesAnIdentifierOfTheRightKind() {
        let typed = ModelID<Author>(author.persistentModelID)
        #expect(typed == author.modelID)
        #expect(typed?.persistentIdentifier == author.persistentModelID)
    }

    @Test func refusesAnIdentifierOfAnotherKind() {
        #expect(ModelID<Author>(book.persistentModelID) == nil)
    }

    @Test func aPredicateOnAnIdentifierMatchesTheRowAlone() throws {
        // The trap find exists for: the author sits in the same row as the book.
        let bookID = book.persistentModelID
        let byRow = try Author.include(#Predicate { $0.persistentModelID == bookID }).results(in: container)
        #expect(byRow.map(\.name) == ["Ursula"])
    }

    @Test func find_isNilForAnIdentifierOfAnotherKind() throws {
        let found = try Author.find(book.persistentModelID, in: container)
        #expect(found == nil)
    }

    @Test func find_isNilForAnotherContainersIdentifier() throws {
        let other = try ModelContainer(for: Author.self, Book.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let stranger = Author(name: "Octavia")
        other.mainContext.insert(stranger)
        try other.mainContext.save()

        let found = try Author.find(stranger.modelID, in: container)
        #expect(found == nil)
    }

    @Test func find_returnsTheModelForItsOwnIdentifier() throws {
        let foundAuthor = try Author.find(author.modelID, in: container)
        let foundBook = try Book.find(book.modelID, in: container)
        #expect(foundAuthor === author)
        #expect(foundBook === book)
    }

    @Test func find_followsALinkOnARow() throws {
        let row = BookSelection(book)
        let linked = try #require(row.author)

        let found = try Author.find(linked, in: container)
        #expect(found === author)
    }

    @Test func decodesOnlyAnIdentifierOfItsOwnKind() throws {
        let data = try JSONEncoder().encode(book.modelID)

        let decoded = try JSONDecoder().decode(ModelID<Book>.self, from: data)
        #expect(decoded == book.modelID)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ModelID<Author>.self, from: data)
        }
    }

    @available(macOS 26, iOS 26, watchOS 26, *)
    @Test func aSubclassIdentifierConvertsToItsParentsAndFindsTheModel() throws {
        let sessions = try ModelContainer(for: Session.self, Visit.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let visit = Visit(startedAt: Date(), mood: 3)
        sessions.mainContext.insert(visit)
        try sessions.mainContext.save()

        let asSession = ModelID<Session>(visit.modelID)
        #expect(asSession.persistentIdentifier == visit.persistentModelID)

        let found = try Session.find(asSession, in: sessions)
        #expect(found === visit)
    }
}
