import Foundation
import SwiftData
import SwiftQuery

enum Genre: String, Codable {
    case fiction, history
}

extension Genre: SnapshotConvertible {}

@Snapshotable
@Model
final class Author {
    var name: String
    var born: Date?
    @Relationship(deleteRule: .cascade, inverse: \Book.author)
    var books: [Book]

    @Transient var greeting: String = ""

    var bookCount: Int { books.count }

    init(name: String, born: Date? = nil, books: [Book] = []) {
        self.name = name
        self.born = born
        self.books = books
    }
}

@Snapshotable
@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var genre: Genre
    var tags: [String]
    var author: Author?

    init(id: UUID = UUID(), title: String, genre: Genre, tags: [String] = [], author: Author? = nil) {
        self.id = id
        self.title = title
        self.genre = genre
        self.tags = tags
        self.author = author
    }
}
