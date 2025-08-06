import Dependencies
import SwiftData

@Model final class Empty {
    init() {}
}

enum DefaultModelContainerKey: DependencyKey {
    static var liveValue: ModelContainer {
        reportIssue(
      """
      A blank, in-memory persistent container is being used for the app.
      Override this dependency in the entry point of your app using `prepareDependencies`.
      """
        )
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Empty.self, configurations: configuration)
    }

    static var testValue: ModelContainer {
        liveValue
    }
}

public extension DependencyValues {
    var modelContainer: ModelContainer {
        get { self[DefaultModelContainerKey.self] }
        set { self[DefaultModelContainerKey.self] = newValue }
    }
}
