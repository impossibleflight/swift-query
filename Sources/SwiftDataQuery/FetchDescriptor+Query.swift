//  FetchDescriptor+Query.swift
//  Persistence//  swift-query
//
//  Created by John Clayton on 2025/4/19.
//  Copyright © 2025 Impossible Flight, LLC. All rights reserved.
//
import Foundation
import SwiftData

public extension FetchDescriptor {
    func filter(_ predicate: Predicate<T>) -> Self {
        FetchDescriptor(predicate: predicate, sortBy: sortBy)
    }

    func filter(_ predicate: () -> Predicate<T>) -> Self {
        FetchDescriptor(predicate: predicate(), sortBy: sortBy)
    }

    func sort(_ sortDescriptor: SortDescriptor<T>) -> Self {
        FetchDescriptor(predicate: predicate, sortBy: sortBy + [sortDescriptor])
    }

    func reverse() -> Self {
        FetchDescriptor(predicate: predicate, sortBy: sortBy.map { $0.reversed() } )
    }

    func exclude() -> Self {
        guard let predicate else { return self }
        let excludePredicate = #Predicate{ item in
            !predicate.evaluate(item)
        }

        return FetchDescriptor(predicate: excludePredicate, sortBy: sortBy)
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
