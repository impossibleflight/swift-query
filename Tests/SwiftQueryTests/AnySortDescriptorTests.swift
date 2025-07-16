import Foundation
import SwiftData
@testable import SwiftQuery
import Testing

struct AnySortDescriptorTests {
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

    @Test func initWithNonDefaultOrder() async throws {
        let descriptor = AnySortDescriptor<Person>(\.name, order: .reverse)
        #expect(descriptor.order == .reverse)
        let sortDescriptor = descriptor.sortDescriptor
        #expect(sortDescriptor.order == .reverse)
    }

    @Test func initWithComparableKeyPath() async throws {
        let descriptor = AnySortDescriptor<Person>(\.age, order: .forward)
        #expect(descriptor.order == .forward)
        let sortDescriptor = descriptor.sortDescriptor
        #expect(sortDescriptor.order == .forward)
    }

    @Test func initWithOptionalComparableKeyPath() async throws {
        let descriptor = AnySortDescriptor<Person>(\.name.first, order: .forward)
        #expect(descriptor.order == .forward)
        let sortDescriptor = descriptor.sortDescriptor
        #expect(sortDescriptor.order == .forward)
    }

    @Test func initWithStringKeyPath() async throws {
        let descriptor = AnySortDescriptor<Person>(\.name)
        let sortDescriptor = descriptor.sortDescriptor
        // String descriptors default to forward order
        #expect(sortDescriptor.order == .forward)
    }

    @Test func initWithStringKeyPathAndOrder() async throws {
        let descriptor = AnySortDescriptor<Person>(\.name, order: .reverse)
        #expect(descriptor.order == .reverse)
        let sortDescriptor = descriptor.sortDescriptor
        #expect(sortDescriptor.order == .reverse)
    }

    @Test func initWithStringComparator() async throws {
        let descriptor = AnySortDescriptor<Person>(\.name, comparator: .localized)
        let sortDescriptor = descriptor.sortDescriptor
        #expect(sortDescriptor.order == .forward)
    }

    @Test func reverseForward() async throws {
        let descriptor = AnySortDescriptor<Person>(\.age, order: .forward)
        let reversed = descriptor.reversed()
        #expect(reversed.order == .reverse)
        #expect(reversed.sortDescriptor.order == .reverse)
    }

    @Test func reverseReverse() async throws {
        let descriptor = AnySortDescriptor<Person>(\.age, order: .reverse)
        let reversed = descriptor.reversed()
        #expect(reversed.order == .forward)
        #expect(reversed.sortDescriptor.order == .forward)
    }

    @Test func sortOnInt() async throws {
        let descriptor = AnySortDescriptor<Person>(\.age, order: .forward)
        let byAgeForward = models.sorted { $0.age < $1.age }
        #expect(models.sorted(using: [descriptor.sortDescriptor]) == byAgeForward)
    }

    @Test func sortOnIntReversed() async throws {
        let descriptor = AnySortDescriptor<Person>(\.age, order: .forward).reversed()
        let byAgeReversed = models.sorted { $0.age > $1.age }
        #expect(models.sorted(using: [descriptor.sortDescriptor]) == byAgeReversed)
    }

    @Test func sortOnString() async throws {
        let descriptor = AnySortDescriptor<Person>(\.name, order: .forward)
        let byNameForward = models.sorted { $0.name < $1.name }
        #expect(models.sorted(using: [descriptor.sortDescriptor]) == byNameForward)
    }

    @Test func sortOnStringReversed() async throws {
        let descriptor = AnySortDescriptor<Person>(\.name, order: .forward).reversed()
        let byNameReversed = models.sorted { $0.name > $1.name }
        #expect(models.sorted(using: [descriptor.sortDescriptor]) == byNameReversed)
    }

    @Test func multipleSort() async throws {
        let nameDescriptor = AnySortDescriptor<Person>(\.name, order: .forward)
        let ageDescriptor = AnySortDescriptor<Person>(\.age, order: .forward)
        
        let descriptors = [nameDescriptor.sortDescriptor, ageDescriptor.sortDescriptor]
        let expected = models.sorted { first, second in
            if first.name != second.name {
                return first.name < second.name
            }
            return first.age < second.age
        }
        
        #expect(models.sorted(using: descriptors) == expected)
    }

    @Test func multipleSortReversed() async throws {
        let nameDescriptor = AnySortDescriptor<Person>(\.name, order: .forward)
            .reversed()
        let ageDescriptor = AnySortDescriptor<Person>(\.age, order: .forward)
            .reversed()

        let descriptors = [nameDescriptor.sortDescriptor, ageDescriptor.sortDescriptor]
        let expected = models.sorted { first, second in
            if first.name != second.name {
                return first.name > second.name
            }
            return first.age > second.age
        }
        
        #expect(models.sorted(using: descriptors) == expected)
    }
}
