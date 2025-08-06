import Foundation
import OSLog

let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "",
    category: "SwiftDataSharing"
)

func debug(_ operation: () -> Void) {
    if
        let isEnabledArgument = ProcessInfo.processInfo.environment["com.impossibleflight.SwiftQuery.debug"],
        let isEnabled = Bool(isEnabledArgument)
    {
        if isEnabled {
            operation()
        }
    }
}

func trace(_ operation: () -> Void) {
    if
        let isEnabledArgument = ProcessInfo.processInfo.environment["com.impossibleflight.SwiftQuery.trace"],
        let isEnabled = Bool(isEnabledArgument)
    {
        if isEnabled {
            operation()
        }
    }
}
