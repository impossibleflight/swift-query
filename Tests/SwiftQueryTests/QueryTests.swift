import Foundation
import SwiftData
@testable import SwiftQuery
import Testing

struct QueryTests {
    let models: [Person] = [
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
    ]

    @Test func includeQuery_Match() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let query = Person.include(predicate)
        let model = Person(name: "Jack")
        try #expect(query.predicate?.evaluate(model) == true)
    }

    @Test func includeQuery_NoMatch() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let query = Person.include(predicate)
        let model = Person(name: "Jill")
        try #expect(query.predicate?.evaluate(model) == false)
    }

    @Test func excludeQuery_Match() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let query = Person.exclude(predicate)
        let model = Person(name: "Jill")
        try #expect(query.predicate?.evaluate(model) == true)
    }

    @Test func excludeQuery_NoMatch() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let query = Person.exclude(predicate)
        let model = Person(name: "Jack")
        try #expect(query.predicate?.evaluate(model) == false)
    }

    @Test func sortByKeyPath() async throws {
        let query = Person.sortBy(\.name)
        let byNameForward =  models.sorted { $0.name < $1.name }
        #expect(models.sorted(using: query.sortDescriptors) == byNameForward)
    }

    @Test func sortByKeyPathAndDirection() async throws {
        let query = Person.sortBy(\.name, order: .reverse)
        let byNameReversed =  models.sorted { $0.name > $1.name }
        #expect(models.sorted(using: query.sortDescriptors) == byNameReversed)
    }

    @Test func sortByMultiple() async throws {
        let query = Person
            .sortBy(\.name)
            .sortBy(\.age)

        let descriptors = [SortDescriptor<Person>(\.name), SortDescriptor<Person>(\.age)]
        let byNameThenAge =  models.sorted(using: descriptors)
        #expect(models.sorted(using: query.sortDescriptors) == byNameThenAge)
    }

    @Test func reverseSortBy() async throws {
        let query = Person
            .sortBy(\.name)
            .reverse()

        let byNameReversed = models.sorted { $0.name > $1.name }
        #expect(models.sorted(using: query.sortDescriptors) == byNameReversed)
    }

    @Test func reverseSortByMultiple() async throws {
        let query = Person
            .sortBy(\.name, order: .forward)
            .sortBy(\.age, order: .reverse)
            .reverse()

        let descriptors: [SortDescriptor<Person>] = [
            .init(\.name, order: .reverse),
            .init(\.age, order: .forward),
            ]
        let multipleReverseSorted = models.sorted(using: descriptors)
        #expect(models.sorted(using: query.sortDescriptors) == multipleReverseSorted)
    }

    @Test func range() async throws {
        var query = Person[0..<5]
        #expect(query.fetchOffset == 0)
        #expect(query.fetchLimit == 5)

        query = Person[5..<10]
        #expect(query.fetchOffset == 5)
        #expect(query.fetchLimit == 5)

        query = Person[75..<100]
        #expect(query.fetchOffset == 75)
        #expect(query.fetchLimit == 25)

        query = Person[19..<27]
        #expect(query.fetchOffset == 19)
        #expect(query.fetchLimit == 8)
    }
}
