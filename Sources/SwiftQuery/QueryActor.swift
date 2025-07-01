import Foundation
import SwiftData

@ModelActor
public actor QueryActor: Sendable {
    public func perform<T>(
        _ block: @Sendable (isolated QueryActor) async throws -> T
    ) async rethrows -> T {
        try await block(self)
    }
}

public extension ModelContainer {
    func queryActor() -> QueryActor {
        .init(modelContainer: self)
    }
}
