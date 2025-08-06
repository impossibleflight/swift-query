import Foundation
import CoreData
import Dependencies
import SwiftData

@MainActor
@propertyWrapper
public final class FetchResults<Model: PersistentModel> {
    public var wrappedValue: FetchResultsCollection<Model>?
    private var subscription: Task<Void, Never> = Task { }

    public init(_ query: Query<Model>, batchSize: Int = 20) {
        subscribe(fetchDescriptor: query.fetchDescriptor, batchSize: batchSize)
    }

    deinit {
        subscription.cancel()
    }

    private func subscribe(fetchDescriptor: FetchDescriptor<Model>, batchSize: Int) {
        debug { logger.debug("\(Self.self).\(#function)") }
        subscription = Task {
            do {
                @Dependency(\.modelContainer) var modelContainer
                var descriptor = fetchDescriptor
                descriptor.includePendingChanges = false
                wrappedValue = try modelContainer.mainContext.fetch(descriptor, batchSize: batchSize)

                let changeNotifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)

                for try await _ in changeNotifications {
                    guard !Task.isCancelled else { break }
                    debug { logger.debug("\(Self.self).NSPersistentStoreRemoteChange")}
                    let result = try modelContainer.mainContext.fetch(descriptor, batchSize: batchSize)
                    trace {
                        logger.trace("\(Self.self).fetchedResults: \(String(describing: result.map { $0.persistentModelID } ))")
                    }
                    wrappedValue = result
                }
            } catch {
                logger.error("\(error)")
            }
        }
    }
}
