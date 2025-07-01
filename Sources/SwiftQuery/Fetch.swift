import Foundation
import SwiftData

@MainActor
public extension Query {
    func first(in container: ModelContainer) throws -> T? {
        var descriptor = self
        descriptor.fetchLimit = 1
        let result = try container.mainContext.fetch(descriptor)
        return result.first
    }

    func last(in container: ModelContainer) throws -> T? {
        try reverse().first(in: container)
    }

    func results(in container: ModelContainer) throws -> [T] {
        try container.mainContext.fetch(self)
    }

    func fetchedResults(
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
        guard predicate != nil else {
            throw Error.missingPredicate
        }
        guard let found = try first(in: container) else {
            let created = body()
            container.mainContext.insert(created)
            return created
        }
        return found
    }

    func delete(in container: ModelContainer) throws {
        let results = try results(in: container)
        results.forEach {
            container.mainContext.delete($0)
        }
    }
}

public extension Query {
    enum Error: Swift.Error, LocalizedError {
        case missingPredicate

        public var errorDescription: String? {
            switch self {
            case .missingPredicate:
                return "Cannot find without a predicate"
            }
        }
    }
}
