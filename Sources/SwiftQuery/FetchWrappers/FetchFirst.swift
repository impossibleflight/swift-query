import Foundation
import CoreData
import Dependencies
import SwiftData
#if canImport(SwiftUI)
import SwiftUI
#endif

@MainActor
@propertyWrapper
public final class FetchFirst<Model: PersistentModel> {
    private var reference: Reference = .init()
    public var wrappedValue: Model? {
        reference.wrappedValue
    }
    private var subscription: (Task<Void, Never>)?

    public init(_ query: Query<Model>) {
        subscribe(query)
    }

    deinit {
        subscription?.cancel()
    }

    private func subscribe(_ query: Query<Model>) {
        debug { logger.debug("\(Self.self).\(#function)(query: \(String(describing: query))") }
        subscription = Task {
            do {
                @Dependency(\.modelContainer) var modelContainer
                let initialResult = try query.first(in: modelContainer)
                reference.wrappedValue = initialResult

                let changeNotifications = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)

                for try await _ in changeNotifications {
                    guard !Task.isCancelled else { break }
                    debug { logger.debug("\(Self.self).NSPersistentStoreRemoteChange")}
                    let result = try query.first(in: modelContainer)
                    trace { logger.trace("\(Self.self).fetchedResults: \(String(describing: result?.persistentModelID))") }
                    reference.wrappedValue = result
                }
            } catch {
                logger.error("\(error)")
            }
        }
    }

    private class Reference {
        var wrappedValue: Model?
        init() {}
    }
}

#if canImport(SwiftUI)
extension FetchFirst: DynamicProperty {}
#endif

