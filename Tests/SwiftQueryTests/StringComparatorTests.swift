import Foundation
import SwiftData
@testable import SwiftQuery
import Testing

@MainActor
struct StringComparatorTests {
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

    @Test func sortBy_stringComparator_localized() throws {
        let query = Query<Person>().sortBy(\.name, comparator: .localized, order: .forward)
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 11)
        #expect(results.first?.name == "Domingo")
        #expect(results.last?.name == "William")
        
        // Verify sorted order
        for i in 0..<results.count-1 {
            #expect(results[i].name.localizedCompare(results[i+1].name) != .orderedDescending)
        }
    }

    @Test func sortBy_stringComparator_localizedReverse() throws {
        let query = Query<Person>().sortBy(\.name, comparator: .localized, order: .reverse)
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 11)
        #expect(results.first?.name == "William")
        #expect(results.last?.name == "Domingo")
        
        // Verify reverse sorted order
        for i in 0..<results.count-1 {
            #expect(results[i].name.localizedCompare(results[i+1].name) != .orderedAscending)
        }
    }

    @Test func sortBy_stringComparator_localizedStandard() throws {
        let query = Query<Person>().sortBy(\.name, comparator: .localizedStandard, order: .forward)
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 11)
        #expect(results.first?.name == "Domingo")
        #expect(results.last?.name == "William")
    }

    @Test func sortBy_stringComparator_lexical() throws {
        // Add person with different case to test lexical sorting
        let testPerson = Person(name: "anna", age: 25)
        modelContainer.mainContext.insert(testPerson)
        try modelContainer.mainContext.save()
        
        let query = Query<Person>().sortBy(\.name, comparator: .lexical, order: .forward)
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 12)
        #expect(results.last?.name == "anna") // Lowercase comes after all uppercase in lexical sorting
        
        // Clean up
        modelContainer.mainContext.delete(testPerson)
        try modelContainer.mainContext.save()
    }

    @Test func sortBy_stringComparator_multipleDescriptors() throws {
        // Test combining string comparator with other sort descriptors
        let query = Query<Person>()
            .sortBy(\.name, comparator: .localized, order: .forward)
            .sortBy(\.age, order: .reverse)
        
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 11)
        
        // Find the two Jacks and verify they're sorted by age (reverse)
        let jacks = results.filter { $0.name == "Jack" }
        #expect(jacks.count == 2)
        
        let jackIndex1 = results.firstIndex { $0.name == "Jack" && $0.age == 19 }!
        let jackIndex2 = results.firstIndex { $0.name == "Jack" && $0.age == 17 }!
        
        #expect(jackIndex1 < jackIndex2) // Older Jack should come first
    }

    @Test func sortBy_stringComparator_withReverse() throws {
        let query = Query<Person>()
            .sortBy(\.name, comparator: .localized, order: .forward)
            .reverse()
        
        let results = try query.results(in: modelContainer)
        
        #expect(results.count == 11)
        #expect(results.first?.name == "William")
        #expect(results.last?.name == "Domingo")
    }
}