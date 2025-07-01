import Foundation
import SwiftData

public typealias Query = FetchDescriptor

public extension Query {
    func include(_ predicate: Predicate<T>) -> Self {
        Query(predicate: predicate, sortBy: sortBy)
    }

    func exclude(_ predicate: Predicate<T>) -> Self {
        let excludePredicate = #Predicate{ item in
            !predicate.evaluate(item)
        }

        return Query(predicate: excludePredicate, sortBy: sortBy)
    }

    func sortBy(_ sortDescriptor: SortDescriptor<T>) -> Self {
        Query(predicate: predicate, sortBy: sortBy + [sortDescriptor])
    }

    func reverse() -> Self {
        Query(predicate: predicate, sortBy: sortBy.map {
            $0.reversed() }
        )
    }

    subscript(_ range: Range<Int>) -> Self {
        get {
            var query = Query(predicate: predicate, sortBy: sortBy)
            query.fetchOffset = range.lowerBound
            query.fetchLimit = range.upperBound - range.lowerBound
            return query
        }
    }
}

private extension SortDescriptor {
    func reversed() -> Self {
        let newOrder: SortOrder = switch self.order {
        case .forward: .reverse
        case .reverse: .forward
        }

        // Changing the order of the sort descriptor has no impact on a resulting
        // sort using this descriptor and we can only get a partial keypath from
        // the property, so we have to unbox the keypath and concstruct a new descriptor.
        // Feedback: FB18433460
        return Self(fullKeyPath(), order: newOrder)
    }

    func fullKeyPath<Value>() -> KeyPath<Compared, Value> & Sendable {
        switch self.keyPath {
        case let path as any KeyPath<Compared, Value> & Sendable:
            return path

        default:
            preconditionFailure("Unhandled keypath type! (\(type(of: keyPath)))")
        }
    }
}
