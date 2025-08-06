import Foundation
import Dependencies
import IssueReporting
import SwiftData
import SwiftQuery
import Testing

@MainActor
struct FetchWrapperTests {
    let modelContainer: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Person.self, configurations: config)
    }

    @Test func fetchFirst_reflectsChanges() async throws {
        try await withDependencies {
            $0.modelContainer = modelContainer
        } operation: {
            @FetchFirst(.jack)
            var jack: Person?
            #expect(jack == nil)

            modelContainer.mainContext.insert(Person(name: "Jack", age: 25))
            try modelContainer.mainContext.save()
            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(jack != nil)
            #expect(jack?.age == 25)
            
            jack?.age = 30
            try modelContainer.mainContext.save()
            
            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(jack?.age == 30)
        }
    }

    @Test func fetchAll_reflectsChanges() async throws {
        try await withDependencies {
            $0.modelContainer = modelContainer
        } operation: {
            @FetchAll(.adults) var adults: [Person]

            #expect(adults.isEmpty)

            let alice = Person(name: "Alice", age: 25)
            let bob = Person(name: "Bob", age: 30)
            let charlie = Person(name: "Charlie", age: 20)

            try modelContainer.mainContext.transaction {
                modelContainer.mainContext.insert(alice)
                modelContainer.mainContext.insert(bob)
                modelContainer.mainContext.insert(charlie)
            }

            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(adults.count == 2)
            #expect(adults[0].name == "Alice")
            #expect(adults[1].name == "Bob")

            try modelContainer.mainContext.transaction {
                charlie.age = 35
            }

            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(adults.count == 3)
            #expect(adults[2].name == "Charlie")
            #expect(adults[2].age == 35)

            try modelContainer.mainContext.transaction {
                modelContainer.mainContext.delete(bob)
            }

            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(adults.count == 2)
            #expect(adults[0].name == "Alice")
            #expect(adults[1].name == "Charlie")
        }
    }

    @Test func fetchResults_reflectsChanges() async throws {
        try await withDependencies {
            $0.modelContainer = modelContainer
        } operation: {
            @FetchResults(.adults) var adults: FetchResultsCollection<Person>?

            #expect(adults == nil)

            let alice = Person(name: "Alice", age: 25)
            let bob = Person(name: "Bob", age: 30)
            let charlie = Person(name: "Charlie", age: 20)

            try modelContainer.mainContext.transaction {
                modelContainer.mainContext.insert(alice)
                modelContainer.mainContext.insert(bob)
                modelContainer.mainContext.insert(charlie)
            }

            try await Task.sleep(nanoseconds: 100_000_000)

            let adultsResults = try #require(adults)

            #expect(adultsResults.count == 2)
            #expect(adultsResults[0].name == "Alice")
            #expect(adultsResults[1].name == "Bob")

            try modelContainer.mainContext.transaction {
                charlie.age = 35
            }

            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(adultsResults.count == 3)
//            #expect(adultsResults[2].name == "Charlie")
//            #expect(adultsResults[2].age == 35)
//
//            try modelContainer.mainContext.transaction {
//                modelContainer.mainContext.delete(bob)
//            }
//
//            try await Task.sleep(nanoseconds: 100_000_000)
//
//            #expect(adultsResults.count == 2)
//            #expect(adultsResults[0].name == "Alice")
//            #expect(adultsResults[1].name == "Charlie")
        }
    }

//    @Test func recordsIssue_whenMissingModelContainer() {
//        withKnownIssue {
//            @FetchFirst(
//                predicate: #Predicate<Person> { $0.name == "Test" }
//            ) var person: Person?
//        }
//    }

}


extension Query where T == Person {
    static var jack: Query {
        Person
            .include(#Predicate<Person> { $0.name == "Jack" })
    }


    static var adults: Query {
        Person
            .include(#Predicate<Person> { $0.age >= 25 })
            .sortBy(\.age, order: .forward)
    }
}
