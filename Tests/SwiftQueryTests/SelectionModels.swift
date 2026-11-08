import Foundation
import SwiftData
import SwiftQuery

@Selection(of: Author.self)
struct AuthorSelection {
    let persistentModelID: PersistentIdentifier
    let name: String
    let born: Date?
    let books: [PersistentIdentifier]
}

@Selection(of: Book.self)
struct BookSelection {
    let id: UUID
    let title: String
    let genre: Genre
    let author: PersistentIdentifier?
    var isRead = false
}

/// A public row of an internal model: the initializer stays internal, so this compiles.
@Selection(of: Author.self)
public struct PublicAuthorSelection {
    public let name: String
}

/// A public row of a public model with a public initializer, so the public expansion is compiled.
@Selection(of: Publisher.self, initializer: .public)
public struct PublisherSelection {
    public let persistentModelID: PersistentIdentifier
    public let name: String
}

// MARK: Inheritance

@available(macOS 26, iOS 26, watchOS 26, *)
@Model class Session {
    var startedAt: Date
    var endedAt: Date?
    init(startedAt: Date, endedAt: Date? = nil) {
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

@available(macOS 26, iOS 26, watchOS 26, *)
@Model final class Visit: Session {
    var mood: Int
    init(startedAt: Date, endedAt: Date? = nil, mood: Int) {
        self.mood = mood
        super.init(startedAt: startedAt, endedAt: endedAt)
    }
}

/// Selects properties the model inherits beside its own.
@available(macOS 26, iOS 26, watchOS 26, *)
@Selection(of: Visit.self)
struct VisitSelection {
    let persistentModelID: PersistentIdentifier
    let startedAt: Date
    let endedAt: Date?
    let mood: Int
}
