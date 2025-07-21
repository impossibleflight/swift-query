import Foundation
import SwiftData
import Synchronization
@testable import SwiftQuery
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

    @Test func results() async throws {
        try await modelContainer.queryActor().perform { _ in
            let modelResults = try Person.results()
            let directResults = try Query<Person>().results()
            
            #expect(modelResults.count == directResults.count)
            #expect(modelResults.count == 3)
        }
    }

    @Test func fetchedResults() async throws {
        try await modelContainer.queryActor().perform { _ in
            let modelResultCount = try Person.fetchedResults { results in
                results.count
            }
            
            let directResultCount = try Query<Person>().fetchedResults { results in
                results.count
            }
            
            #expect(modelResultCount == directResultCount)
            #expect(modelResultCount == 3)
        }
    }

    @Test func fetchedResultsWithBatchSize() async throws {
        try await modelContainer.queryActor().perform { _ in
            let modelResultCount = try Person.fetchedResults(batchSize: 2) { results in
                results.count
            }
            
            let directResultCount = try Query<Person>().fetchedResults(batchSize: 2) { results in
                results.count
            }
            
            #expect(modelResultCount == directResultCount)
            #expect(modelResultCount == 3)
        }
    }

    @Test func fetchedResultsClosure() async throws {
        try await modelContainer.queryActor().perform { _ in
            let modelResultCountMutex = Mutex<Int>(0)
            let directResultCountMutex = Mutex<Int>(0)
            
            try Person.fetchedResults { results in
                modelResultCountMutex.withLock { $0 = results.count }
            }
            
            try Query<Person>().fetchedResults { results in
                directResultCountMutex.withLock { $0 = results.count }
            }
            
            let modelResultCount = modelResultCountMutex.withLock { $0 }
            let directResultCount = directResultCountMutex.withLock { $0 }
            
            #expect(modelResultCount == directResultCount)
            #expect(modelResultCount == 3)
        }
    }

    @Test func fetchedResultsWithBatchSizeClosure() async throws {
        try await modelContainer.queryActor().perform { _ in
            let modelResultCountMutex = Mutex<Int>(0)
            let directResultCountMutex = Mutex<Int>(0)
            
            try Person.fetchedResults(batchSize: 2) { results in
                modelResultCountMutex.withLock { $0 = results.count }
            }
            
            try Query<Person>().fetchedResults(batchSize: 2) { results in
                directResultCountMutex.withLock { $0 = results.count }
            }
            
            let modelResultCount = modelResultCountMutex.withLock { $0 }
            let directResultCount = directResultCountMutex.withLock { $0 }
            
            #expect(modelResultCount == directResultCount)
            #expect(modelResultCount == 3)
        }
    }

    @Test func count() async throws {
        try await modelContainer.queryActor().perform { _ in
            let modelCount = try Person.count()
            let directCount = try Query<Person>().count()
            
            #expect(modelCount == directCount)
            #expect(modelCount == 3)
        }
    }

    @Test func isEmpty() async throws {
        try await modelContainer.queryActor().perform { _ in
            let modelIsEmpty = try Person.isEmpty()
            let directIsEmpty = try Query<Person>().isEmpty()
            
            #expect(modelIsEmpty == directIsEmpty)
            #expect(modelIsEmpty == false)
        }
    }

    @Test func findOrCreate() async throws {
        try await modelContainer.queryActor().perform { _ in
            // Test with existing person
            let existingPredicate = #Predicate<Person> { $0.name == "Jack" }
            var modelResult: (name: String, age: Int)?
            var directResult: (name: String, age: Int)?
            
            try Person.include(existingPredicate).findOrCreate(
                body: { Person(name: "Jack", age: 999) },
                operation: { person in
                    modelResult = (person.name, person.age)
                }
            )
            
            try Query<Person>().include(existingPredicate).findOrCreate(
                body: { Person(name: "Jack", age: 999) },
                operation: { person in
                    directResult = (person.name, person.age)
                }
            )
            
            #expect(modelResult?.name == directResult?.name)
            #expect(modelResult?.age == directResult?.age)
            #expect(modelResult?.age != 999) // Should find existing, not create new
        }
    }
}