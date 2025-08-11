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
            @FetchFirst(.jack) var jack: Person?
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

            #expect(adults != nil)
            #expect(adults?.count == 2)
            #expect(adults?[0].name == "Alice")
            #expect(adults?[1].name == "Bob")

            try modelContainer.mainContext.transaction {
                charlie.age = 35
            }

            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(adults?.count == 3)
            #expect(adults?[2].name == "Charlie")
            #expect(adults?[2].age == 35)

            try modelContainer.mainContext.transaction {
                modelContainer.mainContext.delete(bob)
            }

            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(adults?.count == 2)
            #expect(adults?[0].name == "Alice")
            #expect(adults?[1].name == "Charlie")
        }
    }

    @Test func fetchFirst_withDynamicQuery() async throws {
        try await withDependencies {
            $0.modelContainer = modelContainer
        } operation: {
            let viewModel = ViewModel()
            
            let alice = Person(name: "Alice", age: 30)
            let bob = Person(name: "Bob", age: 25)
            
            try modelContainer.mainContext.transaction {
                modelContainer.mainContext.insert(alice)
                modelContainer.mainContext.insert(bob)
            }
            
            try await Task.sleep(nanoseconds: 100_000_000)
            
            viewModel.updateQuery(name: "Alice")
            try await Task.sleep(nanoseconds: 100_000_000)
            
            #expect(viewModel.person?.name == "Alice")
            
            viewModel.updateQuery(name: "Bob")
            try await Task.sleep(nanoseconds: 100_000_000)
            
            #expect(viewModel.person?.name == "Bob")
        }
    }


    @Test func recordsIssue_whenMissingModelContainer() {
        withKnownIssue {
            @FetchFirst(.jack) var jack: Person?
        }
    }
}

@MainActor
@Observable
class ViewModel {
    @ObservationIgnored
    @FetchFirst(Query<Person>()) var person: Person?

    func updateQuery(name: String) {
        let query = Person.include(#Predicate { person in
            person.name == name
        })
        _person = FetchFirst(query)
    }
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
