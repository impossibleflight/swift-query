import Foundation
import SwiftData
import SwiftQuery
import Testing

struct QueryActorTests {
    let modelContainer: ModelContainer

    @MainActor
    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Person.self, configurations: config)
        [
            Person(name: "Jill", age: 27),
        ].forEach { modelContainer.mainContext.insert($0) }
        try modelContainer.mainContext.save()
    }

    @Test func queryActor_perform() async throws {
        let actor = QueryActor(modelContainer: modelContainer)
        
        let count = try await actor.perform { actor in
            try Query<Person>()
                .count()
        }
        
        #expect(count == 1)
    }
}
