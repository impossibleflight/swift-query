import SwiftQueryMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

struct SnapshotableMacroTests {
    private let specs: [String: MacroSpec] = [
        "Snapshotable": MacroSpec(type: SnapshotableMacro.self, conformances: ["SnapshotConvertible"])
    ]

    private func assertExpansion(
        _ source: String,
        expanded: String,
        diagnostics: [DiagnosticSpec] = [],
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        assertMacroExpansion(
            source,
            expandedSource: expanded,
            diagnostics: diagnostics,
            macroSpecs: specs,
            failureHandler: { failure in
                Issue.record(
                    Comment(rawValue: failure.message),
                    sourceLocation: SourceLocation(
                        fileID: failure.location.fileID,
                        filePath: failure.location.filePath,
                        line: failure.location.line,
                        column: failure.location.column
                    )
                )
            },
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    @Test func expandsStoredPropertiesOnly() {
        assertExpansion(
            """
            @Snapshotable
            final class Person {
                var name: String
                var friends: [Person]
                @Transient var cached: Int = 0
                var initial: Character { name.first! }
                var observed: Int { didSet { } }
                static var shared = Person()
            }
            """,
            expanded: """
            final class Person {
                var name: String
                var friends: [Person]
                @Transient var cached: Int = 0
                var initial: Character { name.first! }
                var observed: Int { didSet { } }
                static var shared = Person()

                struct Snapshot: Identifiable, Hashable, Sendable {
                    let persistentModelID: PersistentIdentifier
                    let name: Snapshotted<String>
                    let friends: Snapshotted<[Person]>
                    let observed: Snapshotted<Int>
                    var id: PersistentIdentifier {
                        persistentModelID
                    }
                }

                var snapshot: Snapshot {
                    Snapshot(
                        persistentModelID: persistentModelID,
                        name: name.snapshotValue,
                        friends: friends.snapshotValue,
                        observed: observed.snapshotValue
                    )
                }
            }

            extension Person: SnapshotConvertible {
            }
            """
        )
    }

    @Test func storedIDTakesOverIdentifiable() {
        assertExpansion(
            """
            @Snapshotable
            final class Person {
                var id: UUID
            }
            """,
            expanded: """
            final class Person {
                var id: UUID

                struct Snapshot: Identifiable, Hashable, Sendable {
                    let persistentModelID: PersistentIdentifier
                    let id: Snapshotted<UUID>
                }

                var snapshot: Snapshot {
                    Snapshot(
                        persistentModelID: persistentModelID,
                        id: id.snapshotValue
                    )
                }
            }

            extension Person: SnapshotConvertible {
            }
            """
        )
    }

    @Test func matchesTheModelsAccessLevel() {
        assertExpansion(
            """
            @Snapshotable
            public final class Person {
                public var name: String
                public var friends: [Person]
            }
            """,
            expanded: """
            public final class Person {
                public var name: String
                public var friends: [Person]

                public struct Snapshot: Identifiable, Hashable, Sendable {
                    public let persistentModelID: PersistentIdentifier
                    public let name: Snapshotted<String>
                    public let friends: Snapshotted<[Person]>
                    public var id: PersistentIdentifier {
                        persistentModelID
                    }
                    public init(persistentModelID: PersistentIdentifier, name: Snapshotted<String>, friends: Snapshotted<[Person]>) {
                        self.persistentModelID = persistentModelID
                        self.name = name
                        self.friends = friends
                    }
                }

                public var snapshot: Snapshot {
                    Snapshot(
                        persistentModelID: persistentModelID,
                        name: name.snapshotValue,
                        friends: friends.snapshotValue
                    )
                }
            }

            extension Person: SnapshotConvertible {
            }
            """
        )
    }

    @Test func rejectsNonClass() {
        assertExpansion(
            """
            @Snapshotable
            struct Person {
                var name: String
            }
            """,
            expanded: """
            struct Person {
                var name: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Snapshotable can only be applied to a class", line: 1, column: 1)
            ]
        )
    }

    @Test func requiresExplicitTypes() {
        assertExpansion(
            """
            @Snapshotable
            final class Person {
                var name = ""
                var age: Int
            }
            """,
            expanded: """
            final class Person {
                var name = ""
                var age: Int

                struct Snapshot: Identifiable, Hashable, Sendable {
                    let persistentModelID: PersistentIdentifier
                    let age: Snapshotted<Int>
                    var id: PersistentIdentifier {
                        persistentModelID
                    }
                }

                var snapshot: Snapshot {
                    Snapshot(
                        persistentModelID: persistentModelID,
                        age: age.snapshotValue
                    )
                }
            }

            extension Person: SnapshotConvertible {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Snapshotable needs an explicit type for 'name'", line: 3, column: 9)
            ]
        )
    }
}
