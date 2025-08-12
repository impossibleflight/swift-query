import Foundation
import CoreData
import Dependencies
import SwiftData

@MainActor
@propertyWrapper
public final class FetchResults<Model: PersistentModel> {
    public var wrappedValue: FetchResultsCollection<Model>? {
        storage.wrappedValue
    }
    private var storage: Storage = .init()
    private var subscription: (Task<Void, Never>)?
    @Dependency(\.modelContainer) private var modelContainer

    public init(_ query: Query<Model>, batchSize: Int = 20) {
        subscribe(query, batchSize: batchSize)
    }

    deinit {
        subscription?.cancel()
    }

    private func subscribe(_ query: Query<Model>, batchSize: Int) {
        debug { logger.debug("\(Self.self).\(#function)") }
        subscription = Task {
            do {
                
                let initialResult = try query.fetchedResults(in: modelContainer, batchSize: batchSize)
                trace {
                    logger.trace("\(Self.self).fetchedResults: \(String(describing: initialResult.map { $0.persistentModelID } ))")
                }
                storage.wrappedValue = initialResult

                let changeNotifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)

                for try await _ in changeNotifications {
                    guard !Task.isCancelled else { break }
                    debug { logger.debug("\(Self.self).NSPersistentStoreRemoteChange")}
                    let result = try query.fetchedResults(in: modelContainer, batchSize: batchSize)
                    trace {
                        logger.trace("\(Self.self).fetchedResults: \(String(describing: result.map { $0.persistentModelID } ))")
                    }
                    storage.wrappedValue = result
                }
            } catch {
                logger.error("\(error)")
            }
        }
    }

    @Observable
    internal class Storage {
        var wrappedValue: FetchResultsCollection<Model>?
        init() {}
    }
}
