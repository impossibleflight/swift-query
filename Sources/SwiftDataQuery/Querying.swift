//  Querying.swift
//  swift-query
//
//  Created by John Clayton on 2025/6/21.
//  Copyright © 2025 Impossible Flight, LLC. All rights reserved.
//
import Foundation
import SwiftData

@MainActor
public extension FetchDescriptor {
    func first(in container: ModelContainer) throws -> T? {
        var descriptor = self
        descriptor.fetchLimit = 1
        let result = try container.mainContext.fetch(descriptor)
        return result.first
    }

    func last(container: ModelContainer) throws -> T? {
        try reverse().first(in: container)
    }

    func results(in container: ModelContainer) throws -> [T] {
        try container.mainContext.fetch(self)
    }

    func fetchResults(
        in container: ModelContainer,
        batchSize: Int = 20
    ) throws -> FetchResultsCollection<T> {
        try container.mainContext.fetch(self, batchSize: batchSize)
    }

    func count(in container: ModelContainer) throws -> Int {
        try container.mainContext.fetchCount(self)
    }

    func isEmpty(in container: ModelContainer) throws -> Bool {
        try count(in: container) < 1
    }

    func findOrCreate(
        in container: ModelContainer,
        body: () -> T
    ) throws -> T {
        guard let found = try first(in: container) else {
            let created = body()
            container.mainContext.insert(created)
            return created
        }
        return found
    }

    func delete(in container: ModelContainer) throws {
        try container.mainContext.delete(model: T.self, where: self.predicate)
    }
}
