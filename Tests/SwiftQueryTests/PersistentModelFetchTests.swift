import Foundation
import SwiftData
import Synchronization
import SwiftQuery
import Testing

@MainActor
struct PersistentModelFetchTests {
    let modelContainer: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Person.self, configurations: config)
        [
            Person(name: "Jill", age: 27),
            Person(name: "Jack", age: 17),
            Person(name: "William", age: 87),
        ].forEach { modelContainer.mainContext.insert($0) }
        try modelContainer.mainContext.save()
    }

    @Test func any() throws {
        let modelResult = try Person.any(in: modelContainer)
        #expect(modelResult != nil)
    }

    @Test func results() throws {
        let modelResults = try Person.results(in: modelContainer)
        let directResults = try Query<Person>().results(in: modelContainer)
        
        #expect(modelResults.count == directResults.count)
        #expect(modelResults.count == 3)
    }

    @Test func fetchedResults() throws {
        let modelResults = try Person.fetchedResults(in: modelContainer)
        let directResults = try Query<Person>().fetchedResults(in: modelContainer)
        
        #expect(modelResults.count == directResults.count)
        #expect(modelResults.count == 3)
    }

    @Test func fetchedResultsWithBatchSize() throws {
        let modelResults = try Person.fetchedResults(in: modelContainer, batchSize: 2)
        let directResults = try Query<Person>().fetchedResults(in: modelContainer, batchSize: 2)
        
        #expect(modelResults.count == directResults.count)
        #expect(modelResults.count == 3)
    }

    @Test func count() throws {
        let modelCount = try Person.count(in: modelContainer)
        let directCount = try Query<Person>().count(in: modelContainer)
        
        #expect(modelCount == directCount)
        #expect(modelCount == 3)
    }

    @Test func isEmpty() throws {
        let modelIsEmpty = try Person.isEmpty(in: modelContainer)
        let directIsEmpty = try Query<Person>().isEmpty(in: modelContainer)
        
        #expect(modelIsEmpty == directIsEmpty)
        #expect(modelIsEmpty == false)
    }

    @Test func findOrCreate() throws {
        // Test with existing person
        let existingPredicate = #Predicate<Person> { $0.name == "Jack" }
        let modelResult = try Person.include(existingPredicate).findOrCreate(in: modelContainer) {
            Person(name: "Jack", age: 999)
        }
        let directResult = try Query<Person>().include(existingPredicate).findOrCreate(in: modelContainer) {
            Person(name: "Jack", age: 999)
        }
        
        #expect(modelResult.name == directResult.name)
        #expect(modelResult.age == directResult.age)
        #expect(modelResult.age != 999) // Should find existing, not create new
    }

    @Test func deleteAll() throws {
        #expect(try Person.count(in: modelContainer) == 3)
        
        try Person.deleteAll(in: modelContainer)
        
        #expect(try Person.count(in: modelContainer) == 0)
        #expect(try Person.isEmpty(in: modelContainer) == true)
    }
}

struct PersistentModelConcurrentFetchTests {
    let modelContainer: ModelContainer

    @MainActor
    init() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Person.self, configurations: config)
        [
            Person(name: "Jill", age: 27),
            Person(name: "Jack", age: 17),
            Person(name: "William", age: 87),
        ].forEach { modelContainer.mainContext.insert($0) }
        try modelContainer.mainContext.save()
    }

    @Test func any() async throws {
        try await modelContainer.createQueryActor().perform { _ in
            let modelResult = try Person.any()
            #expect(modelResult != nil)
        }
    }

    @Test func results() async throws {
        try await modelContainer.createQueryActor().perform { _ in
            let modelResults = try Person.results()
            let directResults = try Query<Person>().results()
            
            #expect(modelResults.count == directResults.count)
            #expect(modelResults.count == 3)
        }
    }

    @Test func fetchedResults() async throws {
        try await modelContainer.createQueryActor().perform { _ in
            let modelResult = try Person.fetchedResults()

            let directResult = try Query<Person>().fetchedResults()

            #expect(modelResult.count == directResult.count)
            #expect(modelResult.count == 3)
        }
    }

    @Test func fetchedResultsWithBatchSize() async throws {
        try await modelContainer.createQueryActor().perform { _ in
            let modelResult = try Person.fetchedResults(batchSize: 2)
            
            let directResult = try Query<Person>().fetchedResults(batchSize: 2)
            
            #expect(modelResult.count == directResult.count)
            #expect(modelResult.count == 3)
        }
    }

    @Test func count() async throws {
        try await modelContainer.createQueryActor().perform { _ in
            let modelCount = try Person.count()
            let directCount = try Query<Person>().count()
            
            #expect(modelCount == directCount)
            #expect(modelCount == 3)
        }
    }

    @Test func isEmpty() async throws {
        try await modelContainer.createQueryActor().perform { _ in
            let modelIsEmpty = try Person.isEmpty()
            let directIsEmpty = try Query<Person>().isEmpty()
            
            #expect(modelIsEmpty == directIsEmpty)
            #expect(modelIsEmpty == false)
        }
    }

    @Test func findOrCreate() async throws {
        try await modelContainer.createQueryActor().perform { _ in
            // Test with existing person
            let existingPredicate = #Predicate<Person> { $0.name == "Jack" }

            let modelPerson = try Person.include(existingPredicate).findOrCreate { Person(name: "Jack", age: 999) }
            let directPerson = try Query<Person>().include(existingPredicate).findOrCreate { Person(name: "Jack", age: 999) }
            
            #expect(modelPerson.name == directPerson.name)
            #expect(modelPerson.age == directPerson.age)
            #expect(modelPerson.age != 999) // Should find existing, not create new
        }
    }

    @Test func deleteAll() async throws {
        try await modelContainer.createQueryActor().perform { _ in
            #expect(try Person.count() == 3)
            
            try Person.deleteAll()
            
            #expect(try Person.count() == 0)
            #expect(try Person.isEmpty() == true)
        }
    }
}
