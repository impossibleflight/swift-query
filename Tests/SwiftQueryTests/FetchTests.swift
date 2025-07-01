import Foundation
import SwiftData
@testable import SwiftQuery
import Testing

@MainActor
struct FetchTests {
    let modelContainer: ModelContainer

    init() throws {
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

    @Test func includeQuery_results() throws {
        var query = Query<Person>().include(#Predicate { $0.name == "Jack" })
        var results = try query.results(in: modelContainer)
        #expect(results.count == 2)

        query = Query<Person>().include(#Predicate { $0.age > 18 })
        results = try query.results(in: modelContainer)
        #expect(results.count == 9)
    }

    @Test func includeQuery_first() throws {
        var query = Query<Person>()
            .include(#Predicate { $0.name == "Karina" })

        var result = try query.first(in: modelContainer)
        #expect(result?.name == "Karina")

        query = Query<Person>()
            .include(#Predicate { $0.age > 18 })
            .sortBy(.init(\.age))
        result = try query.first(in: modelContainer)
        #expect(result?.age == 19)
    }

    @Test func includeQuery_last() throws {
        var query = Query<Person>()
            .include(#Predicate { $0.name == "Karina" })

        var result = try query.last(in: modelContainer)
        #expect(result?.name == "Karina")

        query = Query<Person>()
            .include(#Predicate { $0.age > 18 })
            .sortBy(.init(\.age))
        result = try query.last(in: modelContainer)
        #expect(result?.age == 91)
    }

    @Test func excludeQuery_results() throws {
        var query = Query<Person>().exclude(#Predicate { $0.name == "Jack" })
        var results = try query.results(in: modelContainer)
        #expect(results.count == 9)

        query = Query<Person>().exclude(#Predicate { $0.age > 18 })
        results = try query.results(in: modelContainer)
        #expect(results.count == 2)
    }

    @Test func excludeQuery_first() throws {
        var query = Query<Person>()
            .exclude(#Predicate { $0.name == "Karina" })
            .sortBy(.init(\.name))

        var result = try query
            .first(in: modelContainer)
        #expect(result?.name == "Domingo")

        query = Query<Person>()
            .exclude(#Predicate { $0.age > 18 })
            .sortBy(.init(\.age))

        result = try query.first(in: modelContainer)
        #expect(result?.age == 16)
    }

    @Test func excludeQuery_last() throws {
        var query = Query<Person>()
            .exclude(#Predicate { $0.name == "Karina" })
            .sortBy(.init(\.name))

        var result = try query.last(in: modelContainer)
        #expect(result?.name == "William")

        query = Query<Person>()
            .exclude(#Predicate { $0.age > 18 })
            .sortBy(.init(\.age))

        result = try query.last(in: modelContainer)
        #expect(result?.age == 91)
    }

    @Test func count() throws {
        let query = Query<Person>().include(#Predicate { $0.age > 18 })
        let count = try query.count(in: modelContainer)
        #expect(count == 9)
    }

    @Test func isEmpty() throws {
        var query = Query<Person>().include(#Predicate { $0.age > 18 })
        var isEmpty = try query.isEmpty(in: modelContainer)
        #expect(isEmpty == false)

        query = Query<Person>().include(#Predicate { $0.age < 16 })
        isEmpty = try query.isEmpty(in: modelContainer)
        #expect(isEmpty == true)
    }

    @Test func range() throws {
        let baseQuery = Query<Person>()
            .sortBy(.init(\.name))
        let baseResults = try baseQuery.results(in: modelContainer)

        var rangeQuery = baseQuery[0..<5]
        var results = try rangeQuery.results(in: modelContainer)
        #expect(results.count == 5)
        #expect(results.first?.name == "Domingo")
        #expect(results.last?.name == "Jack")

        rangeQuery = baseQuery[5..<11]
        results = try rangeQuery.results(in: modelContainer)
        #expect(results.count == 6)
        #expect(results.first?.name == "Jill")
        #expect(results.last?.name == "William")
    }

    @Test func findOrCreate_failsWithoutPredicate() throws {
        #expect(throws: Query<Person>.Error.missingPredicate, performing: {
            try Person
                .findOrCreate(in: modelContainer) {
                    Person(name: "Ramona", age: 99)
                }
        })
    }

    @Test func findOrCreate_finds() throws {
        let ramona = try Person
            .include(#Predicate { $0.name == "Ramona" })
            .findOrCreate(in: modelContainer) {
                Person(name: "Ramona", age: 99)
            }

        #expect(ramona.age == 20)
    }

    @Test func findOrCreate_creates() throws {
        let ramona = try Person
            .include(#Predicate { $0.name == "Ramona" && $0.age == 99 })
            .findOrCreate(in: modelContainer) {
                Person(name: "Ramona", age: 99)
            }

        #expect(ramona.age == 99)
    }

    @Test func delete_including() throws {
        let query = Query<Person>()
            .include(#Predicate { $0.name == "Ramona" })

        #expect(try query.isEmpty(in: modelContainer) == false)
        try query.delete(in: modelContainer)
        #expect(modelContainer.mainContext.deletedModelsArray.count == 1)
        #expect(try query.isEmpty(in: modelContainer) == true)
    }

    @Test func delete_excluding() throws {
        let query = Query<Person>()
            .exclude(#Predicate { $0.name == "Ramona" })

        try query.delete(in: modelContainer)
        #expect(modelContainer.mainContext.deletedModelsArray.count == 10)
        #expect(try query.isEmpty(in: modelContainer) == true)
    }

    @Test func deleteAll() throws {
        let query = Query<Person>()
        try query.delete(in: modelContainer)
        #expect(modelContainer.mainContext.deletedModelsArray.count == 11)
        #expect(try query.isEmpty(in: modelContainer) == true)
    }
}
