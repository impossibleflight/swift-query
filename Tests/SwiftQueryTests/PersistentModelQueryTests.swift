import Foundation
import SwiftData
@testable import SwiftQuery
import Testing

struct PersistentModelQueryTests {
    @Test func include() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let modelQuery = Person.include(predicate)
        let directQuery = Query<Person>().include(predicate)
        
        let testModel = Person(name: "Jack")
        #expect(try modelQuery.predicate?.evaluate(testModel) == directQuery.predicate?.evaluate(testModel))
    }

    @Test func exclude() async throws {
        let predicate = #Predicate<Person> { $0.name == "Jack" }
        let modelQuery = Person.exclude(predicate)
        let directQuery = Query<Person>().exclude(predicate)
        
        let testModel = Person(name: "Jill")
        #expect(try modelQuery.predicate?.evaluate(testModel) == directQuery.predicate?.evaluate(testModel))
    }

    @Test func `subscript`() async throws {
        let modelQuery = Person[0..<5]
        let directQuery = Query<Person>()[0..<5]
        
        #expect(modelQuery.range == directQuery.range)
    }

    @Test func sortByComparable() async throws {
        let modelQuery = Person.sortBy(\.age, order: .reverse)
        let directQuery = Query<Person>().sortBy(\.age, order: .reverse)
        
        #expect(modelQuery.sortDescriptors.count == directQuery.sortDescriptors.count)
        #expect(modelQuery.sortDescriptors.first?.order == directQuery.sortDescriptors.first?.order)
    }

    @Test func sortByOptionalComparable() async throws {
        let modelQuery = Person.sortBy(\.name, order: .forward)
        let directQuery = Query<Person>().sortBy(\.name, order: .forward)
        
        #expect(modelQuery.sortDescriptors.count == directQuery.sortDescriptors.count)
        #expect(modelQuery.sortDescriptors.first?.order == directQuery.sortDescriptors.first?.order)
    }

    @Test func sortByString() async throws {
        let modelQuery = Person.sortBy(\.name, comparator: .localized, order: .reverse)
        let directQuery = Query<Person>().sortBy(\.name, comparator: .localized, order: .reverse)
        
        #expect(modelQuery.sortDescriptors.count == directQuery.sortDescriptors.count)
        #expect(modelQuery.sortDescriptors.first?.order == directQuery.sortDescriptors.first?.order)
    }

    @Test func sortByOptionalString() async throws {
        let modelQuery = Person.sortBy(\.name, comparator: .localizedStandard, order: .forward)
        let directQuery = Query<Person>().sortBy(\.name, comparator: .localizedStandard, order: .forward)
        
        #expect(modelQuery.sortDescriptors.count == directQuery.sortDescriptors.count)
        #expect(modelQuery.sortDescriptors.first?.order == directQuery.sortDescriptors.first?.order)
    }
}
