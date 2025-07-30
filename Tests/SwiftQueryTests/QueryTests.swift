import Foundation
import SwiftData
import SwiftQuery
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

    @Test func includeQuery_match() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let query = Person.include(predicate)
        let model = Person(name: "Jack")
        try #expect(query.predicate?.evaluate(model) == true)
    }

    @Test func includeQuery_noMatch() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let query = Person.include(predicate)
        let model = Person(name: "Jill")
        try #expect(query.predicate?.evaluate(model) == false)
    }

    @Test func excludeQuery_match() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let query = Person.exclude(predicate)
        let model = Person(name: "Jill")
        try #expect(query.predicate?.evaluate(model) == true)
    }

    @Test func excludeQuery_noMatch() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let query = Person.exclude(predicate)
        let model = Person(name: "Jack")
        try #expect(query.predicate?.evaluate(model) == false)
    }

    @Test func excludeQuery_impossibleFilter() async throws {
        let impossibleFilter = #Predicate<Person> { $0.age < 0 }

        let universalQuery = Person.exclude(impossibleFilter)

        let testPeople = [
            Person(name: "Baby", age: 0),
            Person(name: "Teen", age: 15),
            Person(name: "Adult", age: 30),
            Person(name: "Elderly", age: 85),
        ]

        for person in testPeople {
            try #expect(universalQuery.predicate?.evaluate(person) == true)
        }
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
        #expect(query.fetchDescriptor.fetchOffset == 0)
        #expect(query.fetchDescriptor.fetchLimit == 5)

        query = Person[5..<10]
        #expect(query.fetchDescriptor.fetchOffset == 5)
        #expect(query.fetchDescriptor.fetchLimit == 5)

        query = Person[75..<100]
        #expect(query.fetchDescriptor.fetchOffset == 75)
        #expect(query.fetchDescriptor.fetchLimit == 25)

        query = Person[19..<27]
        #expect(query.fetchDescriptor.fetchOffset == 19)
        #expect(query.fetchDescriptor.fetchLimit == 8)
    }

    @Test func compoundInclude() async throws {
        let ageFilter = #Predicate<Person> { $0.age >= 18 }
        let nameFilter = #Predicate<Person> { $0.name == "Jack" }
        
        let query = Person.include(ageFilter).include(nameFilter)
        
        let adultJack = Person(name: "Jack", age: 19)
        try #expect(query.predicate?.evaluate(adultJack) == true)
        
        let minorJack = Person(name: "Jack", age: 16)
        try #expect(query.predicate?.evaluate(minorJack) == false)
        
        let adultJill = Person(name: "Jill", age: 25)
        try #expect(query.predicate?.evaluate(adultJill) == false)
        
        let minorJill = Person(name: "Jill", age: 15)
        try #expect(query.predicate?.evaluate(minorJill) == false)
    }

    @Test func compoundExclude() async throws {
        let youngFilter = #Predicate<Person> { $0.age < 18 }
        let nameFilter = #Predicate<Person> { $0.name == "Jack" }
        
        let query = Person.exclude(youngFilter).exclude(nameFilter)
        
        let adultJill = Person(name: "Jill", age: 25)
        try #expect(query.predicate?.evaluate(adultJill) == true)
        
        let adultJack = Person(name: "Jack", age: 19)
        try #expect(query.predicate?.evaluate(adultJack) == false)
        
        let minorJill = Person(name: "Jill", age: 15)
        try #expect(query.predicate?.evaluate(minorJill) == false)
        
        let minorJack = Person(name: "Jack", age: 16)
        try #expect(query.predicate?.evaluate(minorJack) == false)
    }

    @Test func mixedIncludeExclude() async throws {
        let ageFilter = #Predicate<Person> { $0.age >= 18 }
        let nameFilter = #Predicate<Person> { $0.name == "Jack" }
        
        let query = Person.include(ageFilter).exclude(nameFilter)
        
        let adultJill = Person(name: "Jill", age: 25)
        try #expect(query.predicate?.evaluate(adultJill) == true)
        
        let adultJack = Person(name: "Jack", age: 19)
        try #expect(query.predicate?.evaluate(adultJack) == false)
        
        let minorJill = Person(name: "Jill", age: 15)
        try #expect(query.predicate?.evaluate(minorJill) == false)
        
        let minorJack = Person(name: "Jack", age: 16)
        try #expect(query.predicate?.evaluate(minorJack) == false)
    }

    @Test func mixedCompoundPredicate() async throws {
        let ageRange = #Predicate<Person> { $0.age >= 20 && $0.age <= 30 }
        let excludeName = #Predicate<Person> { $0.name == "Ramona" }
        let includePrefix = #Predicate<Person> { $0.name.starts(with: "J") }
        
        let query = Person
            .include(ageRange)
            .exclude(excludeName) 
            .include(includePrefix)
        
        let validJack = Person(name: "Jack", age: 25)
        try #expect(query.predicate?.evaluate(validJack) == true)
        
        let oldJill = Person(name: "Jill", age: 35)
        try #expect(query.predicate?.evaluate(oldJill) == false)
        
        let ramona = Person(name: "Ramona", age: 25)
        try #expect(query.predicate?.evaluate(ramona) == false)
        
        let tom = Person(name: "Tom", age: 25)
        try #expect(query.predicate?.evaluate(tom) == false)
    }

    @Test func complexCompoundFilters() async throws {
        let adultFilter = #Predicate<Person> { $0.age >= 18 }
        let jackFilter = #Predicate<Person> { $0.name == "Jack" }
        let jillFilter = #Predicate<Person> { $0.name == "Jill" }
        let elderlyFilter = #Predicate<Person> { $0.age >= 80 }
        
        let jackQuery = Person.include(adultFilter).include(jackFilter).exclude(elderlyFilter)
        let jillQuery = Person.include(adultFilter).include(jillFilter).exclude(elderlyFilter)
        
        let youngAdultJack = Person(name: "Jack", age: 25)
        let elderlyJack = Person(name: "Jack", age: 85)
        let minorJack = Person(name: "Jack", age: 16)
        
        try #expect(jackQuery.predicate?.evaluate(youngAdultJack) == true)
        try #expect(jackQuery.predicate?.evaluate(elderlyJack) == false)
        try #expect(jackQuery.predicate?.evaluate(minorJack) == false)
        
        let youngAdultJill = Person(name: "Jill", age: 30)
        let elderlyJill = Person(name: "Jill", age: 90)
        
        try #expect(jillQuery.predicate?.evaluate(youngAdultJill) == true)
        try #expect(jillQuery.predicate?.evaluate(elderlyJill) == false)
    }

    @Test func compoundFilterOrderIndependence() async throws {
        let ageFilter = #Predicate<Person> { $0.age >= 18 }
        let nameFilter = #Predicate<Person> { $0.name == "Jack" }
        
        // Two queries with different order
        let query1 = Person.include(ageFilter).exclude(nameFilter)
        let query2 = Person.exclude(nameFilter).include(ageFilter)
        
        let testCases = [
            Person(name: "Jill", age: 25), // Should match both
            Person(name: "Jack", age: 19), // Should match neither
            Person(name: "Tom", age: 16),  // Should match neither
        ]
        
        for person in testCases {
            let result1 = try query1.predicate?.evaluate(person)
            let result2 = try query2.predicate?.evaluate(person)
            #expect(result1 == result2, "Order of include/exclude should not matter for \(person.name), age \(person.age)")
        }
    }

    @Test func compoundFilterWithNoIntersection() async throws {
        let adultFilter = #Predicate<Person> { $0.age >= 18 }
        let minorFilter = #Predicate<Person> { $0.age < 18 }
        
        let impossibleQuery = Person.include(adultFilter).include(minorFilter)
        
        let testPeople = [
            Person(name: "Adult", age: 25),
            Person(name: "Minor", age: 15),
            Person(name: "Elderly", age: 85),
            Person(name: "Teen", age: 17),
        ]
        
        for person in testPeople {
            try #expect(impossibleQuery.predicate?.evaluate(person) == false)
        }
    }

}
