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

    @Test func defaultQuery() async throws {
        try await modelContainer.queryActor().perform { _ in
            let results = try Query<Person>().results()
            #expect(results.count == 11)
        }
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
                .sortBy(\.age)
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
                .sortBy(\.age)
            result = try query.last()
            #expect(result?.age == 91)
        }
    }

    @Test func includeQuery_fetchedResults() async throws {
        try await modelContainer.queryActor().perform { _ in
            let query = Query<Person>().include(#Predicate { $0.name == "Jack" })
            try query.fetchedResults { results in
                #expect(results.count == 2)
                #expect(results.allSatisfy { $0.name == "Jack" })
            }
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
                .sortBy(\.name)

            var result = try query
                .first()
            #expect(result?.name == "Domingo")

            query = Query<Person>()
                .exclude(#Predicate { $0.age > 18 })
                .sortBy(\.age)

            result = try query.first()
            #expect(result?.age == 16)
        }
    }

    @Test func excludeQuery_last() async throws {
        try await modelContainer.queryActor().perform { _ in
            var query = Query<Person>()
                .exclude(#Predicate { $0.name == "Karina" })
                .sortBy(\.name)

            var result = try query.last()
            #expect(result?.name == "William")

            query = Query<Person>()
                .exclude(#Predicate { $0.age > 18 })
                .sortBy(\.age)

            result = try query.last()
            #expect(result?.age == 17)
        }
    }

    @Test func excludeQuery_fetchedResults() async throws {
        try await modelContainer.queryActor().perform { _ in
            let query = Query<Person>().exclude(#Predicate { $0.name == "Jack" })
            try query.fetchedResults { results in
                #expect(results.count == 9)
                #expect(results.allSatisfy { $0.name != "Jack" })
            }
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

    @Test func range() async throws {
        try await modelContainer.queryActor().perform { _ in
            let baseQuery = Query<Person>()
                .sortBy(\.name)

            var rangeQuery = baseQuery[0..<5]
            var results = try rangeQuery.results()
            #expect(results.count == 5)
            #expect(results.first?.name == "Domingo")
            #expect(results.last?.name == "Jack")

            rangeQuery = baseQuery[5..<11]
            results = try rangeQuery.results()
            #expect(results.count == 6)
            #expect(results.first?.name == "Jill")
            #expect(results.last?.name == "William")
        }
    }

    @Test func range_fetchedResults() async throws {
        try await modelContainer.queryActor().perform { _ in
            let query = Query<Person>()
                .sortBy(\.name)[0..<5]
            
            try query.fetchedResults { results in
                #expect(results.count == 5)
                #expect(results.first?.name == "Domingo")
                #expect(results.last?.name == "Jack")
            }
        }
    }

    @Test func findOrCreate_failsWithoutPredicate() async throws {
        _ = await modelContainer.queryActor().perform { actor in
            #expect(throws: Query<Person>.Error.missingPredicate, performing: {
                try Person
                    .findOrCreate(
                        isolation: actor,
                        body: { Person(name: "Ramona", age: 99) },
                        operation: { _ in }
                    )
            })
        }
    }

    @Test func findOrCreate_finds() async throws {
        try await modelContainer.queryActor().perform { _ in
            var foundAge: Int?
            try Person
                .include(#Predicate { $0.name == "Ramona" })
                .findOrCreate(
                    body: { Person(name: "Ramona", age: 99) },
                    operation: { person in
                        foundAge = person.age
                    }
                )

            #expect(foundAge == 20)
        }
    }

    @Test func findOrCreate_creates() async throws {
        try await modelContainer.queryActor().perform { _ in
            var createdAge: Int?
            try Person
                .include(#Predicate { $0.name == "Ramona" && $0.age == 99 })
                .findOrCreate(
                    body: { Person(name: "Ramona", age: 99) },
                    operation: { person in
                        createdAge = person.age
                    }
                )

            #expect(createdAge == 99)
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

    @Test func compoundInclude_results() async throws {
        try await modelContainer.queryActor().perform { actor in

            let ageFilter = #Predicate<Person> { $0.age >= 18 }
            let nameFilter = #Predicate<Person> { $0.name == "Jack" }

            let query = Person.include(ageFilter).include(nameFilter)
            let results = try query.results()

            #expect(results.count == 1)
            #expect(results.first?.name == "Jack")
            #expect(results.first?.age == 19)
        }
    }

    @Test func compoundExclude_results() async throws {
        try await modelContainer.queryActor().perform { actor in
            let youngFilter = #Predicate<Person> { $0.age < 18 }
            let jackFilter = #Predicate<Person> { $0.name == "Jack" }

            let query = Person.exclude(youngFilter).exclude(jackFilter)
            let results = try query.results()

            #expect(results.count == 8)
            #expect(results.allSatisfy { $0.age >= 18 })
            #expect(results.allSatisfy { $0.name != "Jack" })
        }
    }

    @Test func mixedIncludeExclude_results() async throws {
        try await modelContainer.queryActor().perform { actor in
            let adultFilter = #Predicate<Person> { $0.age >= 50 }
            let tommyFilter = #Predicate<Person> { $0.name == "Tommy" }

            let query = Person.include(adultFilter).exclude(tommyFilter)
            let results = try query.results()

            #expect(results.count == 3)
            #expect(results.allSatisfy { $0.age >= 50 })
            #expect(results.allSatisfy { $0.name != "Tommy" })

            let names = results.map { $0.name }.sorted()
            #expect(names == ["Eugenia", "Karina", "William"])
        }
    }

    @Test func compoundPredicate_with_sorting() async throws {
        try await modelContainer.queryActor().perform { actor in
            let ageFilter = #Predicate<Person> { $0.age >= 20 && $0.age <= 50 }
            let query = Person.include(ageFilter).sortBy(\.age)
            let results = try query.results()

            #expect(results.count == 4)

            let ages = results.map { $0.age }
            #expect(ages == [20, 27, 38, 45])

            let names = results.map { $0.name }
            #expect(names == ["Ramona", "Jill", "Domingo", "Grady"])
        }
    }

    @Test func compoundPredicate_count() async throws {
        try await modelContainer.queryActor().perform { actor in
            let ageRangeFilter = #Predicate<Person> { $0.age >= 20 && $0.age < 60 }
            let query = Person.include(ageRangeFilter)
            let count = try query.count()

            #expect(count == 5)
        }
    }

    @Test func compoundPredicate_first() async throws {
        try await modelContainer.queryActor().perform { actor in
            let ageFilter = #Predicate<Person> { $0.age >= 18 }
            let query = Person.include(ageFilter).sortBy(\.age)
            let result = try query.first()

            #expect(result?.name == "Jack")
            #expect(result?.age == 19)
        }
    }

    @Test func compoundPredicate_last() async throws {
        try await modelContainer.queryActor().perform { actor in
            let ageFilter = #Predicate<Person> { $0.age < 80 }
            let query = Person.include(ageFilter).sortBy(\.age)
            let result = try query.last()

            #expect(result?.name == "Karina")
            #expect(result?.age == 67)
        }
    }

    @Test func compoundPredicate_isEmpty() async throws {
        try await modelContainer.queryActor().perform { actor in
            let impossibleFilter1 = #Predicate<Person> { $0.age > 100 }
            let impossibleFilter2 = #Predicate<Person> { $0.age < 0 }
            let query = Person.include(impossibleFilter1).include(impossibleFilter2)

            let isEmpty = try query.isEmpty()
            let count = try query.count()
            #expect(isEmpty == true)
            #expect(count == 0)
        }
    }

    @Test func contextIsolation() async throws {
        let actor = QueryActor(modelContainer: modelContainer)

        let contextCount = try await actor.perform { actor in
            let newPerson = Person(name: "ActorOnly", age: 30)
            actor.modelContext.insert(newPerson)

            return try Query<Person>()
                .include(#Predicate { $0.name == "ActorOnly" })
                .count()
        }

        #expect(contextCount == 1)

        // Main context should not see the actor's changes since they're not propagated
        let mainContextCount = try await MainActor.run {
            try Query<Person>()
                .include(#Predicate { $0.name == "ActorOnly" })
                .count(in: modelContainer)
        }

        #expect(mainContextCount == 0)
    }

    @Test func concurrentQueries() async throws {
        let actor = modelContainer.queryActor()

        async let adultCount = actor.perform { actor in
            try Query<Person>()
                .include(#Predicate { $0.age >= 18 })
                .count()
        }

        async let minorCount = actor.perform { actor in
            try Query<Person>()
                .include(#Predicate { $0.age < 18 })
                .count()
        }

        async let totalCount = actor.perform { actor in
            try Query<Person>().count()
        }


        #expect(try await adultCount == 9)
        #expect(try await minorCount == 2)
        #expect(try await totalCount == 11)
    }

    @Test func perform_singleMutation() async throws {
        let cumulativeAge = try await modelContainer.queryActor().perform { actor in
            let people = try Query<Person>().results()
            return people.reduce(0) { $0 + $1.age }
        }

        try await modelContainer.queryActor().perform { actor in
            let people = try! Query<Person>().results()
            #expect(people.count == 11)

            for person in people { person.age += 1 }

            try actor.modelContext.save()
        }

        let newAge = try await modelContainer.queryActor().perform { _ in
            let people = try Query<Person>().results()
            return people.reduce(0) { $0 + $1.age }
        }
        
        #expect(newAge == cumulativeAge + 11)
    }

    @Test func performMultipleMutation() async throws {
        try await modelContainer.queryActor().perform { actor in
            let firstYoungJack = try Query<Person>()
                .include(#Predicate { $0.name == "Jack" && $0.age == 17 })
                .first()

            let youngJack = try #require(firstYoungJack)
            youngJack.age = 25

            try actor.modelContext.save()
        }

        try await modelContainer.queryActor().perform { actor in
            let adultJacks = try Query<Person>()
                .include(#Predicate { $0.name == "Jack" && $0.age >= 18 })
                .results()

            #expect(adultJacks.count == 2)

            let firstModifiedJack = try Query<Person>()
                .include(#Predicate { $0.name == "Jack" && $0.age == 25 })
                .first()

            let modifiedJack = try #require(firstModifiedJack)
            modifiedJack.age = 75

            try actor.modelContext.save()
        }

        try await modelContainer.queryActor().perform { _ in
            let seniorJacks = try Query<Person>()
                .include(#Predicate { $0.name == "Jack" && $0.age >= 65 })
                .results()
            #expect(seniorJacks.count == 1)
        }
    }

    @Test func performConcurrentMutation() async throws {
        @Sendable func incrementJacks(by amount: Int) async throws {
            try await modelContainer.queryActor().perform { actor in
                let jacks = try Query<Person>()
                    .include(#Predicate { $0.name == "Jack"})
                    .results()

                #expect(jacks.count == 2)

                for jack in jacks {
                    jack.age += amount
                }

                try actor.modelContext.save()
            }
        }

        @Sendable func jacksAge() async throws -> Int {
            try await modelContainer.queryActor().perform { actor in
                let jacks = try Query<Person>()
                    .include(#Predicate { $0.name == "Jack"})
                    .results()
                return jacks.reduce(0) { $0 + $1.age }
            }
        }

        let iterations = 2
        let increment = 1

        let age = try await jacksAge()

        try await withThrowingDiscardingTaskGroup { group in
            (0..<2).forEach { _ in
                group.addTask { try await incrementJacks(by: increment) }
                group.addTask  { try await incrementJacks(by: increment) }
            }
        }

        let newAge = try await jacksAge()

        #expect(newAge == age + (iterations * increment))
    }

    @Test func queryWithCustomActor() async throws {
        let actor = MyActor(modelContainer: modelContainer)
        try await actor.fetch()
    }
}

@ModelActor
actor MyActor {
    func fetch() throws {
        let results = try Query<Person>().results()
        #expect(results.count == 11)
    }
}
