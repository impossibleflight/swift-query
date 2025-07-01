import Foundation
import SwiftData

extension PersistentModel {
    static func include(_ predicate: Predicate<Self>) -> Query<Self> {
        query().include(predicate)
    }

    static func exclude(_ predicate: Predicate<Self>) -> Query<Self> {
        query().exclude(predicate)
    }

    static func sortBy(_ sortDescriptor: SortDescriptor<Self>) -> Query<Self> {
        query().sortBy(sortDescriptor)
    }

    static func query(_ fetchDescriptor: Query<Self> = .init()) -> Query<Self> {
        fetchDescriptor
    }

    static subscript(_ range: Range<Int>) -> Query<Self> {
        get {
            query()[range]
        }
    }
}
