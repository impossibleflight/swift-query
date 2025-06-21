//  AsyncQuerying.swift
//  swift-query
//
//  Created by John Clayton on 2025/6/21.
//  Copyright © 2025 Impossible Flight, LLC. All rights reserved.
//
import Foundation
import SwiftData

public extension FetchDescriptor {
    func first(isolation: isolated (any ModelActor) = #isolation) throws -> T? {
        var descriptor = self
        descriptor.fetchLimit = 1
        let result = try isolation.modelContext.fetch(descriptor)
        return result.first
    }

    func last(isolation: isolated (any ModelActor) = #isolation) throws -> T? {
        try reverse().first(isolation: isolation)
    }

    func results(isolation: isolated (any ModelActor) = #isolation) throws -> [T] {
        try isolation.modelContext.fetch(self)
    }

    /// Error: Pattern that the region based isolation checker does not understand how to check. Please file a bug
//    func fetchResults(
//        batchSize: Int = 20,
//        isolation: isolated (any ModelActor) = #isolation
//    ) throws -> FetchResultsCollection<T> {
//        try isolation.modelContext.fetch(self, batchSize: batchSize)
//    }

    func count(isolation: isolated (any ModelActor) = #isolation) throws -> Int {
        try isolation.modelContext.fetchCount(self)
    }

    func isEmpty(isolation: isolated (any ModelActor) = #isolation) throws -> Bool {
        try count(isolation: isolation) < 1
    }

    func findOrCreate(
        isolation: isolated (any ModelActor) = #isolation,
        body: () -> T
    ) throws -> T {
        guard let found = try first() else {
            let created = body()
            isolation.modelContext.insert(created)
            return created
        }
        return found
    }

    func delete(isolation: isolated (any ModelActor) = #isolation) throws {
        try isolation.modelContext.delete(model: T.self, where: self.predicate)
    }
}
