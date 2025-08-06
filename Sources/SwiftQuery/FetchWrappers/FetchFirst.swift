import Foundation
import CoreData
import Dependencies
import SwiftData

@MainActor
@propertyWrapper
public final class FetchFirst<Model: PersistentModel> {
    public var wrappedValue: Model? = nil
    private var subscription: Task<Void, Never> = Task { }

    public init(_ query: Query<Model>) {
        subscribe(fetchDescriptor: query.fetchDescriptor)
    }

    deinit {
        subscription.cancel()
    }

    private func subscribe(fetchDescriptor: FetchDescriptor<Model>) {
        debug { logger.debug("\(Self.self).\(#function)") }
        subscription = Task {
            do {
                @Dependency(\.modelContainer) var modelContainer
                wrappedValue = try modelContainer.mainContext.fetch(fetchDescriptor).first

                let changeNotifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)

                for try await _ in changeNotifications {
                    guard !Task.isCancelled else { break }
                    debug { logger.debug("\(Self.self).NSPersistentStoreRemoteChange")}
                    let result = try modelContainer.mainContext.fetch(fetchDescriptor).first
                    trace { logger.trace("\(Self.self).fetchedResults: \(String(describing: result?.persistentModelID))") }
                    wrappedValue = result
                }
            } catch {
                logger.error("\(error)")
            }
        }
    }
}
