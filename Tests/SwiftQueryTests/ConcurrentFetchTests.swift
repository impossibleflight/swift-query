import Foundation
import SwiftData
@testable import SwiftQuery
import Testing

struct ConcurrentFetchTests {
    let modelContainer: ModelContainer

    @MainActor
    init() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Person.self, configurations: config)
        [
            Person(name: "Jill", age: 27),
            Person(name: "Jack", age: 17),
            Person(name: "Jack", age: 19),
            Person(name: "William", age: 87),
            Person(name: "Ramona", age: 20),
            Person(name: "Eugenia", age: 56),
            Person(name: "Tommy", age: 91),
            Person(name: "Grady", age: 45),
            Person(name: "Rory", age: 16),
            Person(name: "Domingo", age: 38),
            Person(name: "Karina", age: 67),
        ].forEach { modelContainer.mainContext.insert($0) }
        try modelContainer.mainContext.save()
    }

    @Test func includeQuery_results() async throws {
        try await modelContainer.queryActor().perform { _ in
            var query = Query<Person>().include(#Predicate { $0.name == "Jack" })
            var results = try query.results()
            #expect(results.count == 2)

            query = Query<Person>().include(#Predicate { $0.age > 18 })
            results = try query.results()
            #expect(results.count == 9)
        }
    }

    @Test func includeQuery_first() async throws {
        try await modelContainer.queryActor().perform { _ in
            var query = Query<Person>()
                .include(#Predicate { $0.name == "Karina" })

            var result = try query.first()
            #expect(result?.name == "Karina")

            query = Query<Person>()
                .include(#Predicate { $0.age > 18 })
                .sortBy(.init(\.age))
            result = try query.first()
            #expect(result?.age == 19)
        }
    }

    @Test func includeQuery_last() async throws {
        try await modelContainer.queryActor().perform { _ in
            var query = Query<Person>()
                .include(#Predicate { $0.name == "Karina" })

            var result = try query.last()
            #expect(result?.name == "Karina")

            query = Query<Person>()
                .include(#Predicate { $0.age > 18 })
                .sortBy(.init(\.age))
            result = try query.last()
            #expect(result?.age == 91)
        }
    }

    @Test func excludeQuery_results() async throws {
        try await modelContainer.queryActor().perform { _ in
            var query = Query<Person>().exclude(#Predicate { $0.name == "Jack" })
            var results = try query.results()
            #expect(results.count == 9)

            query = Query<Person>().exclude(#Predicate { $0.age > 18 })
            results = try query.results()
            #expect(results.count == 2)
        }
    }

    @Test func excludeQuery_first() async throws {
        try await modelContainer.queryActor().perform { _ in
            var query = Query<Person>()
                .exclude(#Predicate { $0.name == "Karina" })
                .sortBy(.init(\.name))

            var result = try query
                .first()
            #expect(result?.name == "Domingo")

            query = Query<Person>()
                .exclude(#Predicate { $0.age > 18 })
                .sortBy(.init(\.age))

            result = try query.first()
            #expect(result?.age == 16)
        }
    }

    @Test func excludeQuery_last() async throws {
        try await modelContainer.queryActor().perform { _ in
            var query = Query<Person>()
                .exclude(#Predicate { $0.name == "Karina" })
                .sortBy(.init(\.name))

            var result = try query.last()
            #expect(result?.name == "William")

            query = Query<Person>()
                .exclude(#Predicate { $0.age > 18 })
                .sortBy(.init(\.age))

            result = try query.last()
            #expect(result?.age == 91)
        }
    }

    @Test func count() async throws {
        try await modelContainer.queryActor().perform { _ in
            let query = Query<Person>().include(#Predicate { $0.age > 18 })
            let count = try query.count()
            #expect(count == 9)
        }
    }

    @Test func isEmpty() async throws {
        try await modelContainer.queryActor().perform { _ in
            var query = Query<Person>().include(#Predicate { $0.age > 18 })
            var isEmpty = try query.isEmpty()
            #expect(isEmpty == false)

            query = Query<Person>().include(#Predicate { $0.age < 16 })
            isEmpty = try query.isEmpty()
            #expect(isEmpty == true)
        }
    }

    @Test func findOrCreate_failsWithoutPredicate() async throws {
        _ = await modelContainer.queryActor().perform { actor in
            #expect(throws: Query<Person>.Error.missingPredicate, performing: {
                try Person
                    .findOrCreate(isolation: actor) {
                        Person(name: "Ramona", age: 99)
                    }
            })
        }
    }

    @Test func findOrCreate_finds() async throws {
        try await modelContainer.queryActor().perform { _ in
            let ramona = try Person
                .include(#Predicate { $0.name == "Ramona" })
                .findOrCreate() {
                    Person(name: "Ramona", age: 99)
                }

            #expect(ramona.age == 20)
        }
    }

    @Test func findOrCreate_creates() async throws {
        try await modelContainer.queryActor().perform { _ in
            let ramona = try Person
                .include(#Predicate { $0.name == "Ramona" && $0.age == 99 })
                .findOrCreate() {
                    Person(name: "Ramona", age: 99)
                }

            #expect(ramona.age == 99)
        }
    }

    @Test func delete_including() async throws {
        try await modelContainer.queryActor().perform { actor in
            let query = Query<Person>()
                .include(#Predicate { $0.name == "Ramona" })

            #expect(try query.isEmpty() == false)
            try query.delete()
            #expect(actor.modelContext.deletedModelsArray.count == 1)
            #expect(try query.isEmpty() == true)
        }
    }

    @Test func delete_excluding() async throws {
        try await modelContainer.queryActor().perform { actor in
            let query = Query<Person>()
                .exclude(#Predicate { $0.name == "Ramona" })

            try query.delete()
            #expect(actor.modelContext.deletedModelsArray.count == 10)
            #expect(try query.isEmpty() == true)
        }
    }

    @Test func deleteAll() async throws {
        try await modelContainer.queryActor().perform { actor in
            let query = Query<Person>()
            try query.delete()
            #expect(actor.modelContext.deletedModelsArray.count == 11)
            #expect(try query.isEmpty() == true)
        }
    }

}
