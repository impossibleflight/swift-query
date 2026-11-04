import CoreData
import Foundation
import SwiftData
import SwiftQuery
import Testing

/// Checks the generated snapshots against the Core Data model SwiftData builds for the same
/// classes, so a property the macro missed or mapped to the wrong kind shows up here rather than
/// in an app.
@MainActor
struct SnapshotSchemaTests {
    @Test func authorSnapshotIsComplete() throws {
        try expectComplete(Author.self, snapshot: Author(name: "").snapshot)
    }

    @Test func bookSnapshotIsComplete() throws {
        try expectComplete(Book.self, snapshot: Book(title: "", genre: .fiction).snapshot)
    }

    @Test func snapshotMatchesWhatCoreDataReads() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            }
        }

        let container = try ModelContainer(
            for: Author.self, Book.self,
            configurations: ModelConfiguration(url: url)
        )
        let context = container.mainContext
        let author = Author(name: "Ursula", born: Date(timeIntervalSinceReferenceDate: 12345))
        let book = Book(title: "Earthsea", genre: .fiction, tags: ["wizards"], author: author)
        context.insert(author)
        context.insert(book)
        try context.save()
        let bookSnapshot = book.snapshot
        let authorSnapshot = author.snapshot

        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: [Author.self, Book.self]))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try coordinator.addPersistentStore(
            type: .sqlite,
            at: url,
            options: [NSReadOnlyPersistentStoreOption: true, NSPersistentHistoryTrackingKey: true]
        )
        let coreDataContext = NSManagedObjectContext(.mainQueue)
        coreDataContext.persistentStoreCoordinator = coordinator

        let request = NSFetchRequest<NSManagedObject>(entityName: "Book")
        request.predicate = NSPredicate(format: "id == %@", book.id as CVarArg)
        let row = try #require(try coreDataContext.fetch(request).first)

        try expectAttributesMatch(row, snapshot: bookSnapshot)

        let relatedAuthor = try #require(row.value(forKey: "author") as? NSManagedObject)
        #expect(relatedAuthor.value(forKey: "name") as? String == "Ursula")
        let authorID = try #require(bookSnapshot.author)
        let resolvedAuthor = try #require(context.model(for: authorID) as? Author)
        #expect(resolvedAuthor.name == relatedAuthor.value(forKey: "name") as? String)

        let relatedBooks = try #require(relatedAuthor.value(forKey: "books") as? Set<NSManagedObject>)
        let coreDataTitles = Set(relatedBooks.compactMap { $0.value(forKey: "title") as? String })
        let snapshotTitles = Set(authorSnapshot.books.compactMap { (context.model(for: $0) as? Book)?.title })
        #expect(snapshotTitles.count == authorSnapshot.books.count)
        #expect(coreDataTitles == snapshotTitles)
        try expectAttributesMatch(relatedAuthor, snapshot: authorSnapshot)
    }
}

private extension SnapshotSchemaTests {
    func entity<M: PersistentModel>(for type: M.Type) throws -> NSEntityDescription {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: [type]))
        return try #require(model.entitiesByName["\(M.self)"])
    }

    func fields(of snapshot: Any) -> [String: Any] {
        Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: snapshot).children
                .compactMap { child in child.label.map { ($0, child.value) } }
                .filter { $0.0 != "persistentModelID" }
        )
    }

    func expectComplete<M: PersistentModel>(_ type: M.Type, snapshot: Any) throws {
        let entity = try entity(for: type)
        let snapshotFields = fields(of: snapshot)

        let modelled = Set(entity.attributesByName.keys).union(entity.relationshipsByName.keys)
        #expect(Set(snapshotFields.keys) == modelled)

        for (name, relationship) in entity.relationshipsByName {
            let value = try #require(snapshotFields[name])
            let expected: Any.Type = relationship.isToMany
                ? [PersistentIdentifier].self
                : relationship.isOptional ? PersistentIdentifier?.self : PersistentIdentifier.self
            #expect(Swift.type(of: value) == expected, "\(name) should be \(expected), is \(Swift.type(of: value))")
        }

        for (name, attribute) in entity.attributesByName {
            let value = try #require(snapshotFields[name])
            guard let expected = valueType(for: attribute.attributeType) else { continue }
            let actual = String(describing: Swift.type(of: value))
            #expect(actual == "\(expected)" || actual == "Optional<\(expected)>", "\(name) should be \(expected), is \(actual)")
        }
    }

    func expectAttributesMatch(_ object: NSManagedObject, snapshot: Any) throws {
        let snapshotFields = fields(of: snapshot)
        for (name, attribute) in object.entity.attributesByName {
            guard valueType(for: attribute.attributeType) != nil else { continue }
            let stored = object.value(forKey: name).map(normalized)
            let snapshotted = snapshotFields[name].flatMap(unwrapped).map(normalized)
            #expect(stored == snapshotted, "\(name): Core Data has \(String(describing: stored)), snapshot has \(String(describing: snapshotted))")
        }
    }

    func valueType(for attributeType: NSAttributeType) -> Any.Type? {
        switch attributeType {
        case .stringAttributeType: String.self
        case .UUIDAttributeType: UUID.self
        case .dateAttributeType: Date.self
        case .binaryDataAttributeType: Data.self
        case .booleanAttributeType: Bool.self
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType: Int.self
        case .doubleAttributeType, .floatAttributeType: Double.self
        default: nil
        }
    }

    func unwrapped(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        return mirror.children.first?.value
    }

    func normalized(_ value: Any) -> AnyHashable {
        switch value {
        case let number as NSNumber: AnyHashable(number.doubleValue)
        case let integer as any BinaryInteger: AnyHashable(Double(integer))
        case let bool as Bool: AnyHashable(bool ? 1.0 : 0.0)
        case let double as Double: AnyHashable(double)
        case let date as Date: AnyHashable(date.timeIntervalSinceReferenceDate)
        case let hashable as AnyHashable: hashable
        default: AnyHashable(String(describing: value))
        }
    }
}
