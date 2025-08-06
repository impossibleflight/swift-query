import Foundation
import CoreData
import Dependencies
import SwiftData

@MainActor
@propertyWrapper
public final class FetchAll<Model: PersistentModel> {
    public var wrappedValue: [Model] = []
    private var subscription: Task<Void, Never> = Task { }

    public init(_ query: Query<Model>) {
        subscribe(fetchDescriptor: query.fetchDescriptor)
    }

    deinit {
        subscription.cancel()
    }

    private func subscribe(fetchDescriptor: FetchDescriptor<Model>) {
        debug { logger.debug("\(Self.self).\(#function)") }
        subscription = Task { @MainActor in
            // Send initial value
            do {
                @Dependency(\.modelContainer) var modelContainer
                wrappedValue = try modelContainer.mainContext.fetch(fetchDescriptor)

                // Listen for changes
                let changeNotifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)

                for try await _ in changeNotifications {
                    guard !Task.isCancelled else { break }
                    debug { logger.debug("\(Self.self).NSPersistentStoreRemoteChange")}
                    let result = try modelContainer.mainContext.fetch(fetchDescriptor)
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
