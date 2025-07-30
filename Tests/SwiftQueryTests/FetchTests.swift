import Foundation
import SwiftData
import SwiftQuery
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
            .sortBy(\.age)
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
            .sortBy(\.age)
        result = try query.last(in: modelContainer)
        #expect(result?.age == 91)
    }

    @Test func includeQuery_fetchedResults() throws {
        let query = Query<Person>().include(#Predicate { $0.name == "Jack" })
        let results = try query.fetchedResults(in: modelContainer)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.name == "Jack" })
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
            .sortBy(\.name)

        var result = try query
            .first(in: modelContainer)
        #expect(result?.name == "Domingo")

        query = Query<Person>()
            .exclude(#Predicate { $0.age > 18 })
            .sortBy(\.age)

        result = try query.first(in: modelContainer)
        #expect(result?.age == 16)
    }

    @Test func excludeQuery_last() throws {
        var query = Query<Person>()
            .exclude(#Predicate { $0.name == "Karina" })
            .sortBy(\.name)

        var result = try query.last(in: modelContainer)
        #expect(result?.name == "William")

        query = Query<Person>()
            .exclude(#Predicate { $0.age > 18 })
            .sortBy(\.age)

        result = try query.last(in: modelContainer)
        #expect(result?.age == 17)
    }

    @Test func excludeQuery_fetchedResults() throws {
        let query = Query<Person>().exclude(#Predicate { $0.name == "Jack" })
        let results = try query.fetchedResults(in: modelContainer)
        #expect(results.count == 9)
        #expect(results.allSatisfy { $0.name != "Jack" })
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
            .sortBy(\.name)

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

    @Test func range_fetchedResults() throws {
        let query = Query<Person>()
            .sortBy(\.name)[0..<5]
        
        let results = try query.fetchedResults(in: modelContainer)
        
        #expect(results.count == 5)
        #expect(results.first?.name == "Domingo")
        #expect(results.last?.name == "Jack")
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
        let ramona = try Query<Person>()
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

    @Test func compoundInclude_results() throws {
        let ageFilter = #Predicate<Person> { $0.age >= 18 }
        let nameFilter = #Predicate<Person> { $0.name == "Jack" }
        
        let query = Person.include(ageFilter).include(nameFilter)
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 1)
        #expect(results.first?.name == "Jack")
        #expect(results.first?.age == 19)
    }

    @Test func compoundExclude_results() throws {
        let youngFilter = #Predicate<Person> { $0.age < 18 }
        let jackFilter = #Predicate<Person> { $0.name == "Jack" }
        
        let query = Person.exclude(youngFilter).exclude(jackFilter)
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 8)
        #expect(results.allSatisfy { $0.age >= 18 })
        #expect(results.allSatisfy { $0.name != "Jack" })
    }

    @Test func mixedIncludeExclude_results() throws {
        let adultFilter = #Predicate<Person> { $0.age >= 50 }
        let tommyFilter = #Predicate<Person> { $0.name == "Tommy" }
        
        let query = Person.include(adultFilter).exclude(tommyFilter)
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 3)
        #expect(results.allSatisfy { $0.age >= 50 })
        #expect(results.allSatisfy { $0.name != "Tommy" })
        
        let names = results.map { $0.name }.sorted()
        #expect(names == ["Eugenia", "Karina", "William"])
    }

    @Test func compoundPredicate_with_sorting() throws {
        let ageFilter = #Predicate<Person> { $0.age >= 20 && $0.age <= 50 }
        let query = Person.include(ageFilter).sortBy(\.age)
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 4)
        
        let ages = results.map { $0.age }
        #expect(ages == [20, 27, 38, 45])
        
        let names = results.map { $0.name }
        #expect(names == ["Ramona", "Jill", "Domingo", "Grady"])
    }

    @Test func compoundPredicate_count() throws {
        let ageRangeFilter = #Predicate<Person> { $0.age >= 20 && $0.age < 60 }
        let query = Person.include(ageRangeFilter)
        let count = try query.count(in: modelContainer)
        
        #expect(count == 5)
    }

    @Test func compoundPredicate_first() throws {
        let ageFilter = #Predicate<Person> { $0.age >= 18 }
        let query = Person.include(ageFilter).sortBy(\.age)
        let result = try query.first(in: modelContainer)
        
        #expect(result?.name == "Jack")
        #expect(result?.age == 19)
    }

    @Test func compoundPredicate_last() throws {
        let ageFilter = #Predicate<Person> { $0.age < 80 }
        let query = Person.include(ageFilter).sortBy(\.age)
        let result = try query.last(in: modelContainer)
        
        #expect(result?.name == "Karina")
        #expect(result?.age == 67)
    }

    @Test func compoundPredicate_is_empty() throws {
        let impossibleFilter1 = #Predicate<Person> { $0.age > 100 }
        let impossibleFilter2 = #Predicate<Person> { $0.age < 0 }
        let query = Person.include(impossibleFilter1).include(impossibleFilter2)
        
        #expect(try query.isEmpty(in: modelContainer) == true)
        #expect(try query.count(in: modelContainer) == 0)
    }
}
