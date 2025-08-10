import Foundation
import CoreData
import Dependencies
import SwiftData

@MainActor
@propertyWrapper
public final class FetchFirst<Model: PersistentModel> {
    private var storage: Storage = .init()
    public var wrappedValue: Model? {
        storage.wrappedValue
    }
    private var subscription: (Task<Void, Never>)?
    @Dependency(\.modelContainer) private var modelContainer

    public init(_ query: Query<Model>) {
        subscribe(query)
    }

    deinit {
        subscription?.cancel()
    }

    private func subscribe(_ query: Query<Model>) {
        debug { logger.debug("\(Self.self).\(#function)(query: \(String(describing: query))") }
        subscription = Task { [modelContainer = self.modelContainer] in
            do {
                let initialResult = try query.first(in: modelContainer)
                storage.wrappedValue = initialResult

                let changeNotifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)

                for try await _ in changeNotifications {
                    guard !Task.isCancelled else { break }
                    debug { logger.debug("\(Self.self).NSPersistentStoreRemoteChange")}
                    let result = try query.first(in: modelContainer)
                    trace { logger.trace("\(Self.self).fetchedResults: \(String(describing: result?.persistentModelID))") }
                    storage.wrappedValue = result
                }
            } catch {
                logger.error("\(error)")
            }
        }
    }

    @Observable
    internal class Storage {
        var wrappedValue: Model?
        init() {}
    }
}
