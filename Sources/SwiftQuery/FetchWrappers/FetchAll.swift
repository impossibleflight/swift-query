import Foundation
import CoreData
import Dependencies
import SwiftData
#if canImport(SwiftUI)
import SwiftUI
#endif

@MainActor
@propertyWrapper
public final class FetchAll<Model: PersistentModel>: Observable {
    public var wrappedValue: [Model] {
        storage.wrappedValue
    }
    private var storage: Storage = .init()
    private var subscription: (Task<Void, Never>)?
    @Dependency(\.modelContainer) private var modelContainer

    public init(_ query: Query<Model> = .init()) {
        subscribe(query)
    }

    deinit {
        subscription?.cancel()
    }

    private func subscribe(_ query: Query<Model>) {
        debug { logger.debug("\(Self.self).\(#function)(query: \(String(describing: query))") }
        subscription = Task { [modelContainer = self.modelContainer] in
            do {
                let initialResult = try query.results(in: modelContainer)
                trace {
                    logger.trace("\(Self.self).results: \(String(describing: initialResult.map { $0.persistentModelID } ))")
                }
                storage.wrappedValue = initialResult

                let changeNotifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)

                for try await _ in changeNotifications {
                    guard !Task.isCancelled else { break }
                    debug { logger.debug("\(Self.self).NSPersistentStoreRemoteChange")}
                    let result = try query.results(in: modelContainer)
                    trace {
                        logger.trace("\(Self.self).results: \(String(describing: result.map { $0.persistentModelID } ))")
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
        var wrappedValue: [Model] = []
        init() {}
    }
}

#if canImport(SwiftUI)
extension FetchAll: DynamicProperty {}
#endif
