import SwiftQueryMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

struct SelectionMacroTests {
    private let specs: [String: MacroSpec] = [
        "Selection": MacroSpec(type: SelectionMacro.self, conformances: ["Identifiable", "Hashable", "Sendable"])
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

    @Test func fillsEachPropertyFromTheModelByName() {
        assertExpansion(
            """
            @Selection(of: Book.self)
            struct BookRow {
                let persistentModelID: PersistentIdentifier
                let title: String
                let author: PersistentIdentifier?
                var isSelected = false
                var headline: String { title.uppercased() }
                static let empty = BookRow()
            }
            """,
            expanded: """
            struct BookRow {
                let persistentModelID: PersistentIdentifier
                let title: String
                let author: PersistentIdentifier?
                var isSelected = false
                var headline: String { title.uppercased() }
                static let empty = BookRow()

                init(_ model: Book) {
                    self.persistentModelID = model.persistentModelID.snapshotValue
                    self.title = model.title.snapshotValue
                    self.author = model.author.snapshotValue
                }

                var id: PersistentIdentifier {
                    persistentModelID
                }
            }

            extension BookRow: Identifiable, Hashable, Sendable {
            }
            """
        )
    }

    @Test func storedIDTakesOverIdentifiable() {
        assertExpansion(
            """
            @Selection(of: Book.self)
            struct BookRow {
                let id: UUID
                let title: String
            }
            """,
            expanded: """
            struct BookRow {
                let id: UUID
                let title: String

                init(_ model: Book) {
                    self.id = model.id.snapshotValue
                    self.title = model.title.snapshotValue
                }
            }

            extension BookRow: Identifiable, Hashable, Sendable {
            }
            """
        )
    }

    @Test func withoutAnIdentifierTheRowIsNotIdentifiable() {
        assertExpansion(
            """
            @Selection(of: Book.self)
            struct TitleRow {
                let title: String
            }
            """,
            expanded: """
            struct TitleRow {
                let title: String

                init(_ model: Book) {
                    self.title = model.title.snapshotValue
                }
            }

            extension TitleRow: Hashable, Sendable {
            }
            """
        )
    }

    @Test func initializerIsInternalUnlessAsked() {
        assertExpansion(
            """
            @Selection(of: Book.self, initializer: .public)
            public struct BookRow {
                public let persistentModelID: PersistentIdentifier
                public let title: String
            }
            @Selection(of: Book.self)
            public struct TitleRow {
                public let title: String
            }
            """,
            expanded: """
            public struct BookRow {
                public let persistentModelID: PersistentIdentifier
                public let title: String

                public init(_ model: Book) {
                    self.persistentModelID = model.persistentModelID.snapshotValue
                    self.title = model.title.snapshotValue
                }

                public var id: PersistentIdentifier {
                    persistentModelID
                }
            }
            public struct TitleRow {
                public let title: String

                init(_ model: Book) {
                    self.title = model.title.snapshotValue
                }
            }

            extension BookRow: Identifiable, Hashable, Sendable {
            }

            extension TitleRow: Hashable, Sendable {
            }
            """
        )
    }

    @Test func rejectsNonStruct() {
        assertExpansion(
            """
            @Selection(of: Book.self)
            final class BookRow {
                let title: String
            }
            """,
            expanded: """
            final class BookRow {
                let title: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Selection can only be applied to a struct", line: 1, column: 1)
            ]
        )
    }
}
