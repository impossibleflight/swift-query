//  FetchDescriptor+Query.swift
//  swift-query
//
//  Created by John Clayton on 2025/4/19.
//  Copyright © 2025 Impossible Flight, LLC. All rights reserved.
//
import Foundation
import SwiftData

public typealias Query = FetchDescriptor

public extension Query {
    func include(_ predicate: Predicate<T>) -> Self {
        Query(predicate: predicate, sortBy: sortBy)
    }

    func sortBy(_ sortDescriptor: SortDescriptor<T>) -> Self {
        Query(predicate: predicate, sortBy: sortBy + [sortDescriptor])
    }

    func reverse() -> Self {
        Query(predicate: predicate, sortBy: sortBy.map { $0.reversed() } )
    }

    func exclude(_ predicate: Predicate<T>) -> Self {
        let excludePredicate = #Predicate{ item in
            !predicate.evaluate(item)
        }

        return Query(predicate: excludePredicate, sortBy: sortBy)
    }

    subscript(_ range: Range<Int>) -> Self {
        get {
            var descriptor = Query(predicate: predicate, sortBy: sortBy)
            descriptor.fetchOffset = range.lowerBound
            descriptor.fetchLimit = range.upperBound - range.lowerBound
            return descriptor
        }
    }
}

private extension SortDescriptor {
    func reversed() -> Self {
        var clone = self
        clone.order = switch clone.order {
        case .forward:
                .reverse
        case .reverse:
                .forward
        }
        return clone
    }
}
